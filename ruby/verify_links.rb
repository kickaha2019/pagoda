#
# Verify links
#
# Command line
#   Pagoda database directory
#   URL to validate or number of links to validate
#   Cache directory
#   How old in days before revalidating link
#

require 'net/http'
require 'uri'
require 'openssl'
require 'yaml'

require_relative 'pagoda'
require_relative 'common'

class VerifyLinks
  include Common

  def initialize( dir, cache)
    @pagoda   = Pagoda.new( dir, cache)
  end

  def complete_url( base, url)
    return url if /^http(s|):/ =~ url
    raise "Unable to complete #{url} for #{base}" unless /^\// =~ url
    if m = /^([^:]*:\/\/[^\/]*)\//.match( base)
      return m[1] + url
    end
    raise "Unable to complete #{url} for #{base}"
  end

  def get_details( link, body, rec)
    status = true
    rec[:title] = get_title( body, link.type)

    # 404 errors
    if /^IIS.*404.*Not Found$/ =~ rec[:title]
      rec[:valid]   = false
      rec[:comment] = 'Not found'
      return false
    end

    # Server errors
    if /Internal Server Error/i =~ rec[:title]
      rec[:valid]   = false
      rec[:comment] = 'Server error'
      return false
    end

    # Apply site specific filter if link not bound
    unless link.bound?
      @pagoda.get_site_handler( link.site).filter( @pagoda, link, body, rec)
    end
  end

  def get_title( page, defval)
    if m = /<title[^>]*>([^<]*)<\/title>/im.match( page)
      title = m[1].gsub( /\s/, ' ')
      title.strip.gsub( '  ', ' ')
      (title == '') ? defval : title
    else
      defval
    end
  end

  def http_get_threaded( url)
    @http_get_threaded_url = url
    @http_get_threaded_got = nil

    Thread.new do
      begin
        response = http_get_response( url)
        if url == @http_get_threaded_url
          if response.is_a?( Net::HTTPNotFound)
            @http_get_threaded_got = [false, 'Not found']
          else
            @http_get_threaded_got = [true, response]
          end
        end
      rescue Exception => bang
        if url == @http_get_threaded_url
          @http_get_threaded_got = [false, bang.message]
        end
      end
    end

    (0...600).each do
      sleep 0.1
      unless @http_get_threaded_got.nil?
        return * @http_get_threaded_got
      end
    end

    sleep 300
    return false, "Timeout"
  end

  def http_get_with_redirect( site, url, depth = 0)
    overriden, status, comment, response = @pagoda.get_site_handler( site).override_verify_url( url)
    if overriden
      return status, comment, response
    end

    #p ['http_get_with_redirect1', url]
    comment = nil
    status, response = http_get_threaded( url)

    if status && (depth < 4) &&
        response.is_a?( Net::HTTPRedirection) &&
        (/^http(s|):/ =~ response['Location'])

      # Regard as redirected unless temporary redirect
      comment = 'Redirected to ' + response['Location'] if response.code != '302'
      #p ['http_get_with_redirect2', url, redirected, response.code]

      status, comment1, response = http_get_with_redirect( site, response['Location'], depth+1)
      comment = comment1 if comment1
      return status, comment, response
    end

    return status, status ? nil : response, response
  end

  def oldest( n, valid_for)
    free, bound, dubious, ignored = [], [], [], []
    valid_from = Time.now.to_i - 24 * 60 * 60 * valid_for

    @pagoda.links do |link|
      next if link.static? && link.valid? && (link.timestamp > 100)

      if (link.status == 'Invalid') || link.comment
        #puts "Dubious: #{link.url} / #{link.comment}"
        dubious << link
      elsif /free/i =~ link.status
        free << link
      elsif link.status == 'Ignored'
        ignored << link if link.timestamp < valid_from
      else
        bound << link if link.timestamp < valid_from
      end
    end

    puts "... Bound:   #{bound.size}"
    puts "... Dubious: #{dubious.size}"
    puts "... Free:    #{free.size}"
    puts "... Ignored: #{ignored.size}"

    {'free' => free, 'dubious' => dubious, 'bound' => bound}.each_pair do |k,v|
      v.sort_by! {|link| link.timestamp ? link.timestamp : 0}
      File.open( "/Users/peter/temp/#{k}.csv", 'w') do |io|
        io.puts 'site,title,url,timestamp,valid'
        v.each do |link|
          io.puts "#{link.site},#{link.title},#{link.url},#{link.timestamp},#{link.valid}"
        end
      end
    end
    #raise 'Dev'

    links = []
    (0...n).each do |i|
      links << dubious[i] if i < dubious.size
      links << free[i]    if i < free.size
      links << bound[i]   if i < bound.size
      links << ignored[i] if i < ignored.size
    end

    links = links[0...n] if links.size > n
    links.shuffle.each {|rec| yield rec}
  end

  def terminate
    @pagoda.terminate
  end

  def verify_page( link, debug=false)
    status, comment, response = http_get_with_redirect( link.site, link.url)
    p ['verify_page1', status, comment, response] if debug

    if response.is_a?( Net::HTTPMovedPermanently)
      new_url = complete_url( link.url, response['Location'])
      p ['verify_page2', new_url] if debug
      title = (/Moved Permanently/ =~ link.title) ? link.orig_title : link.title
      @pagoda.add_link( link.site, link.type, title, new_url, link.static)
      new_link = @pagoda.link( new_url)
      binds = @pagoda.get( 'bind', :url, link.url)
      if binds.size > 0
        new_link.bind( binds[0][:id])
      end

      link.delete
      verify_page( new_link, debug)
      return
    end

    body = response.is_a?( String) ? response : response.body

    unless status
      if debug
        File.open( "/Users/peter/temp/verify_links.html", 'w') {|io| io.print body}
      end
      puts "*** #{link.url}: #{body}"
    end

    # Try converting odd characters
    begin
      body = body.gsub( '–', '-').gsub( '’', "'")
    rescue
    end

    # Force to US ASCII
    body.force_encoding( 'UTF-8')
    body.encode!( 'US-ASCII',
                  :replace           => ' ',
                  :invalid           => :replace,
                  :undef             => :replace,
                  :universal_newline => true)

    rec = {title:'', timestamp:Time.now.to_i, valid:true, comment:comment, changed: false, ignore:false}

    # Get year if possible for link
    if status
      begin
        @pagoda.get_site_handler( link.site).get_game_year( @pagoda, link, body, rec)
      rescue Exception => bang
        status = false
        rec[:comment] = bang.message
      end
    end

    #
    if status
      #status, valid, ignore, comment, title = get_details( link, body, rec)
      p ['verify_page3', status, rec] if debug
      status = get_details( link, body, rec)
      p ['verify_page4', status, rec] if debug
    else
      rec[:valid] = false
      rec[:title] = link.title
    end

    # Save old timestamp and page, get new unused timestamp
    old_t, old_page, changed = link.timestamp, '', false
    old_path = @pagoda.cache_path( old_t)
    if File.exist?( old_path)
      old_page = IO.read( old_path)
    end

    new_path = @pagoda.cache_path( rec[:timestamp])
    while File.exist?( new_path)
      sleep 1
      rec[:timestamp] = Time.now.to_i
    end

    # If OK save page to cache else to temp area
    File.open( new_path, 'w') {|io| io.print body}
    rec[:changed] = (body.strip != old_page.strip)

    # Ignore link if so flagged unless bound to a game
    if rec[:ignore]
      if link.collation
        rec[:comment] = "Was bound to #{link.collation.name}"
      else
        link.bind( -1)
      end
    end

    link.verified( rec)
    if File.exist?( old_path)
      File.delete( old_path)
    end
  end

  def verify_url( url)
    link = @pagoda.link( url)
    if link
      verify_page( link,true)
    else
      raise "No such link: #{url}"
    end
  end
end

vl = VerifyLinks.new( ARGV[0], ARGV[2])
if /^http/ =~ ARGV[1]
  vl.verify_url( ARGV[1])
  puts "... Verified #{ARGV[1]}"
else
  puts "... Verifying links"
  count = 0
  vl.oldest( ARGV[1].to_i, ARGV[3].to_i) do |link|
    #puts "... Verifying #{link.url}"
    count += 1
    vl.throttle( link.url)
    begin
      vl.verify_page( link)
    rescue
      puts "*** Problem with #{link.url}"
      raise
    end
  end
  puts "... Verified #{count} links"
end
vl.terminate
