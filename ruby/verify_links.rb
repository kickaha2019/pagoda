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

  def initialize( dir)
    @pagoda  = Pagoda.new( dir)
    @filters = YAML.load( IO.read( dir + '/verify_links.yaml'))
    @current = nil
  end

  def apply_filter( filter, link, body, title)
    args = []

    if filter.is_a?( String)
      name = filter
    else
      raise 'Unexpected filters' if filter.size != 1
      name = filter.keys[0]
      args = filter.values[0]
      args = [args] unless args.is_a?( Array)
    end

    status, valid, ignore, title = send( ('filter_' + name).to_sym, link, body, title, * args)
    return status, valid, ignore, title
  end

  def filter_apple_store( link, body, title)
    if m = /^(.*) on the App Store$/.match( title.strip)
      return true, true, false, m[1]
    end
    return false, false, false, title
  end

  def filter_google_play_store( link, body, title)
    return true, true, false, title if /itemprop="genre" href="\/store\/apps\/category\/GAME_(ADVENTURE|CASUAL|PUZZLE|ROLE_PLAYING)"/m =~ body
    return true, false, false, title if /itemprop="genre" href="\/store\/apps\/category\/.*"/m =~ body
    return false, false, false, title
  end

  def filter_steam_store( link, body, title)
    if m = /^(.*) on Steam$/.match( title)
      return true, true, false, m[1]
    end
    return true, true, false,  title if /\/agecheck\/app\// =~ link.url
    return true, true, false,  title if /^Site Error$/ =~ title
    return true, true, true, title if /^Welcome to Steam$/ =~ title
    return false, false, false, title
  end

  def filter_suffix( link, body, title, suffix)
    re = Regexp.new( '^(.*)' + suffix + '.*$')
    if m = re.match( title)
      return true, true, false, m[1]
    else
      return false, false, false, ''
    end
  end

  def get_details( link, body)
    valid  = status = true
    ignore = false
    title  = orig_title = get_title( body, link.type)

    # 404 errors
    if /^IIS.*404.*Not Found$/ =~ title
      return false, false, false, orig_title
    end

    # Server errors
    if /Internal Server Error/i =~ title
      return false, false, false, orig_title
    end

    # Apply site specific filters
    if site = @filters[link.site]
      if filters = site[link.type]
        if filters.is_a?( Array)
          filters.each do |filter|
            status, valid, ignore, title = apply_filter( filter, link, body, title)
            break unless valid && status
          end
        else
          status, valid, ignore, title = apply_filter( filters, link, body, title)
        end
      end
    end

    return status, valid, ignore, (valid ? title : orig_title)
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

  def oldest( n, valid_for)
    links, dubious = [], []
    valid_from = Time.now.to_i - 24 * 60 * 60 * valid_for

    @pagoda.links do |link|
      if (link.status == 'Invalid') || link.redirected?
        dubious << link
      else
        links << link if link.timestamp < valid_from
      end
    end

    links.sort_by! {|link| link.timestamp ? link.timestamp : 0}
    links = dubious + links
    links = links[0...n] if links.size > n

    File.open( '/Users/peter/temp/verify.csv', 'w') do |io|
      io.puts 'site,title,url,timestamp,valid'
      links.each do |link|
        io.puts "#{link.site},#{link.title},#{link.url},#{link.timestamp},#{link.valid}"
      end
    end

    links.shuffle.each {|rec| yield rec}
  end

  def verify_page( link, cache, debug=false)
    t = Time.now.to_i
    @current = link.url
    status, redirected, response = http_get_with_redirect( link.url)
    p ['verify_page1', status, redirected, response] if debug
    body = response.is_a?( String) ? response : response.body

    unless status
      if debug
        File.open( "/Users/peter/temp/verify_links.html", 'w') {|io| io.print body}
      end
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

    status, valid, ignore, title = get_details( link, body)
    p ['verify_page2', status, valid, ignore, title] if debug

    # Save old timestamp and page, get new unused timestamp
    old_t, old_page, changed = link.timestamp, '', false
    if File.exist?( cache + "/#{old_t}.html")
      old_page = IO.read( cache + "/#{old_t}.html")
    end

    while File.exist?( cache + "/#{t}.html")
      sleep 1
      t = Time.now.to_i
    end

    # If OK save page to cache else to temp area
    if status
      File.open( cache + "/#{t}.html", 'w') {|io| io.print body}
      changed = (body.strip != old_page.strip)
    else
      if debug
        File.open( "/Users/peter/temp/verify_links.html", 'w') {|io| io.print body}
      end
      return
    end

    link.verified( title ? title.strip : '', t, valid ? 'Y': 'N', redirected ? 'Y' : 'N', changed)

    if ignore
      link.bind( -1)
    end

    if File.exist?( cache + "/#{old_t}.html")
      File.delete( cache + "/#{old_t}.html")
    end
  end

  def verify_url( url, cache)
    link = @pagoda.link( url)
    if link
      verify_page( link, cache, true)
    else
      raise "No such link: #{url}"
    end
  end
end

vl = VerifyLinks.new( ARGV[0])
if /^http/ =~ ARGV[1]
  vl.verify_url( ARGV[1], ARGV[2])
  puts "... Verified #{ARGV[1]}"
else
  puts "... Verifying links"
  count = 0
  vl.detect_hang
  vl.oldest( ARGV[1].to_i, ARGV[3].to_i) do |link|
    # puts "... Verifying #{link.url}"
    count += 1
    vl.throttle( link.url)
    begin
      vl.verify_page( link, ARGV[2])
    rescue
      puts "*** Problem with #{link.url}"
      raise
    end
  end
  puts "... Verified #{count} links"
end

