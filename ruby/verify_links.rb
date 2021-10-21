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

class VerifyLinks
  def initialize( dir)
    @pagoda  = Pagoda.new( dir)
    @filters = YAML.load( IO.read( dir + '/verify_links.yaml'))
    @touched = Hash.new {|h,k| h[k] = 0}
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

  def detect_hang
    Thread.abort_on_exception = true
    Thread.new do
      last_touch = 0
      while true
        sleep 60
        new_touch = @touched.values.inject {|r,e| (r > e) ? r : e}
        unless new_touch > last_touch
          puts "*** Hang detected for #{@current}"
          exit 1
        end
        last_touch = new_touch
      end
    end
  end

  def filter_google_play_store( link, body, title)
    return true, true, false, title if /itemprop="genre" href="\/store\/apps\/category\/GAME_(ADVENTURE|CASUAL|PUZZLE|ROLE_PLAYING)"/m =~ body
    return true, false, false, title if /itemprop="genre" href="\/store\/apps\/category\/.*"/m =~ body
    return false, false, false, title
  end

  def filter_ios_store( link, body, title)
    return true, true, false, title if /TouchArcade/m =~ body
    return true, true, false, title if /Requires (iOS|iPadOS) \d+(|.\d+)(|.\d+) or later/m =~ body
    return true, true, false, title if /Requires (iOS|iPadOS) \d+(|.\d+)(|.\d+) and the Apple Arcade/m =~ body
    return true, false, false, title if /Requires MacOS \d+(|.\d+)(|.\d+) or later/m =~ body
    return false, false, false, title
  end

  def filter_steam_store( link, body, title)
    if m = /^(.*) on Steam$/.match( title)
      return true, true, m[1]
    end
    return true, true, false,  title if /\/agecheck\/app\// =~ link.url
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
      return false, false, false, title
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

  def http_get( url)
    uri = URI.parse( url)

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept']          = 'text/html,application/xhtml+xml,application/xml'
    request['Accept-Language'] = 'en-gb'
    request['User-Agent']      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

    use_ssl     = uri.scheme == 'https'
    verify_mode = OpenSSL::SSL::VERIFY_NONE

    begin
      response = Net::HTTP.start( uri.hostname, uri.port, :use_ssl => use_ssl, :verify_mode => verify_mode) {|http|
        http.request( request)
      }

      return true, response
    rescue Exception => bang
      return false, bang.message, ''
    end
    #response.value
    #response.body
  end

  def http_get_with_redirect( url, depth = 0)
    #p ['http_get_with_redirect1', url]
    status, response = http_get( url)
    return status, false, response unless status

    if response.is_a?( Net::HTTPNotFound)
      return false, false, response
    end

    if (depth < 4) &&
        response.is_a?( Net::HTTPRedirection) &&
        (/^http(s|):/ =~ response['Location'])

      # Regard as redirected unless temporary redirect
      redirected = (response.code != '302')
      #p ['http_get_with_redirect2', url, redirected, response.code]

      # Hack for Steam to ignore app -> app redirects
      # p ['http_get_with_redirect2', url, response['Location']]
      # if is_steam_url?( response['Location']) && is_steam_url?( url)
      #   p ['http_get_with_redirect3', url, response['Location']]
      #   return status, false, response
      # end

      # Ignore Steam age challenge redirects
      # if /^https:\/\/store.steampowered.com\/agecheck\/app\/\d+($|\/)/ =~ response['Location']
      #   return status, false, response
      # end

      status, _, response = http_get_with_redirect( response['Location'], depth+1)
      return status, redirected, response
    end

    return status, false, response
  end

  # def is_steam_url?( url)
  #   p ['is_steam_url?', url]
  #   /^https:\/\/store\.steampowered\.com\/app\/\d+$/ =~ url
  # end

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

  def throttle( url)
    site = /^(http|https):\/\/([^\/]*)(\/|$)/.match( url)[2]
    if @touched[site] + 10 > Time.now.to_i
      sleep 10
    end
    @touched[site] = Time.now.to_i
  end

  def verify_page( link, cache)
    @current = link.url
    status, redirected, response = http_get_with_redirect( link.url)
    #p ['verify_page1', status, redirected, response]
    return unless status

    body = response.body
    body.force_encoding( 'UTF-8')
    body.encode!( 'US-ASCII',
                  :replace           => ' ',
                  :invalid           => :replace,
                  :undef             => :replace,
                  :universal_newline => true)

    status, valid, ignore, title = get_details( link, body)
    #p ['verify_page2', status, valid, title]
    unless status
      File.open( "/Users/peter/temp/verify_links.html", 'w') {|io| io.print response.body}
      # if link.timestamp < 1000
      #   link.verified( link.title, link.timestamp + 1, 'N', redirected ? 'Y' : 'N')
      # end
      return
    end

    old_t = link.timestamp
    t = Time.now.to_i
    while File.exist?( cache + "/#{t}.html")
      sleep 1
      t = Time.now.to_i
    end
    File.open( cache + "/#{t}.html", 'w') {|io| io.print response.body}

    link.verified( title ? title.strip : '', t, valid ? 'Y': 'N', redirected ? 'Y' : 'N')

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
      verify_page( link, cache)
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

