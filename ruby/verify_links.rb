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

  def get_details( link, body, rec)
    site   = @pagoda.get_site_handler( link.site)
    rec[:title] = site.get_title( link.url, body, link.type)

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

    # Title indicates link deleted
    if @pagoda.get_site_handler( link.site).deleted_title( rec[:title])
      return false
    end

    # Apply site specific filter if link not bound
    unless link.bound?
      @pagoda.get_site_handler( link.site).filter( @pagoda, link, body, rec)
    end
    true
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

  def http_get_with_redirect( site, url, depth = 0, debug = false)
    overriden, status, comment, response = @pagoda.get_site_handler( site).override_verify_url( url)
    if overriden
      return status, comment, response
    end

    p ['http_get_with_redirect1', url] if debug
    comment = nil
    status, response = http_get_threaded( url)

    # Record redirections
    if status && (depth < 4) &&
        response.is_a?( Net::HTTPRedirection)

      location = complete_url( url, response['Location'])
      comment = 'Redirected to ' + location
      p ['http_get_with_redirect2', url, response, response.code] if debug

      status, comment1, response = http_get_with_redirect( site, location, depth+1, debug)
      comment = comment1 if comment1
      return status, comment, response
    end

    return status, status ? nil : response, response
  end

  def load_page( link, debug=false)
    status, comment, response = http_get_with_redirect( link.site, link.url, 0, debug)
    ignore = false
    p ['load_page1', status, comment, response] if debug

    # Ignore redirects if site coerces redirect URL to original URL
    if m = /^Redirected to (.*)$/.match( comment)
      redirect = m[1]
      p ['load_page1a', redirect, @pagoda.get_site_handler( link.site).coerce_url( redirect)] if debug
      if @pagoda.get_site_handler( link.site).coerce_url( redirect).sub( /\/$/, '') == link.url.sub( /\/$/, '')
        comment = nil
      end
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

    return status, comment, ignore, body
  end

  def to_verify(n)
    must, bound, loose = [], [], []

    @pagoda.links do |link|
      if link.static? && link.valid? && (link.timestamp > 100)
        next
      end

      if link.comment
        must << link
        next
      end

      if link.timestamp > 100
        unless @pagoda.cache_read(link.timestamp) != ''
          must << link
          next
        end
      end

      if (link.status == 'Invalid') || link.comment
        #puts "Dubious: #{link.url} / #{link.comment}"
        must << link
      elsif /free/i =~ link.status
        loose << link
      elsif link.status == 'Ignored'
        loose << link
      else
        bound << link
      end
    end

    {'must'  => must,
     'loose' => loose,
     'bound' => bound}.each_pair do |k,v|

      v.sort_by! {|link| link.timestamp ? link.timestamp : 0}
      File.open( "/Users/peter/temp/#{k}.csv", 'w') do |io|
        io.puts 'site,title,url,timestamp,valid'
        v.each do |link|
          io.puts "#{link.site},#{link.title},#{link.url},#{link.timestamp},#{link.valid}"
        end
      end

      v.reverse!
      puts "... #{k}: #{v.size}" unless v.empty?
    end

    links = must
    (0...n).each do
      links << bound.pop unless bound.empty?
      links << loose.pop unless loose.empty?
    end

    links = links[0...n] if links.size > n
    links.shuffle.each {|rec| yield rec}
  end

  def verify_page( link, debug=false)
    if link.static?
      if game = link.collation
        game.update_from_link(link)
      end
      return
    end

    status, comment, ignore, body = load_page(link, debug)
    site = @pagoda.get_site_handler( link.site)
    body = site.post_load(@pagoda, link.url, body) if status

    if status && (comment = site.validate_page(link.url, body))
      status = false
    end

    rec = {title:'',
           timestamp:Time.now.to_i,
           valid:true,
           comment:comment,
           changed: false,
           ignore:ignore}

    # Get year if possible for link
    if status
      begin
        site.get_game_year( @pagoda, link, body, rec)
      rescue Exception => bang
        status = false
        rec[:comment] = bang.message
      end
    end

    # Get details check for link apparently deleted
    if status
      p ['verify_page3', status, rec] if debug
      status = get_details( link, body, rec)
      unless status
        if site.deleted_title( rec[:title])
          p ['verify_page5', link.url] if debug
          link.delete
          return
        end
      end
      p ['verify_page4', status, rec] if debug
    else
      rec[:valid] = false
      rec[:title] = link.title
    end

    @pagoda.update_link(link, rec, body, debug)
    if status && (game = link.collation)
      game.update_from_link(link)
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

  def zap_old_links
    @pagoda.start_transaction
    @pagoda.select( 'old_links') do |rec|
      @pagoda.delete( 'old_links', :url, rec[:url])
    end
    @pagoda.end_transaction
  end
end

vl = VerifyLinks.new( ARGV[0], ARGV[2])
if /^http/ =~ ARGV[1]
  vl.verify_url( ARGV[1])
  puts "... Verified #{ARGV[1]}"
else
  puts "... Verifying links"
  vl.zap_old_links
  count = 0
  vl.to_verify(ARGV[1].to_i) do |link|
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
