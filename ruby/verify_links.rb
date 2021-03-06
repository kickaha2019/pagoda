require 'net/http'
require 'uri'
require 'openssl'
require 'yaml'

require_relative 'database'

class VerifyLinks
  def initialize( dir)
    @database = Database.new( dir)
    @filters = YAML.load( IO.read( dir + '/verify_links.yaml'))
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

    status, valid, title = send( ('filter_' + name).to_sym, link, body, title, * args)
    return status, valid, title
  end

  def filter_ios_store( link, body, title)
    return true, true, title if /Requires (iOS|iPadOS) \d+(|.\d+) or later/m =~ body
    return true, false, title if /Requires macOS \d+(|.\d+) or later/m =~ body
    return false, false, title
  end

  def filter_suffix( link, body, title, suffix)
    re = Regexp.new( '^(.*)' + suffix + '.*$')
    if m = re.match( title)
      return true, true, m[1]
    else
      return false, false, ''
    end
  end

  def get_details( link, body)
    status      = true
    valid       = true
    title       = get_title( body)

    # 404 errors
    if /^IIS.*404.*Not Found$/ =~ title
      return false, false, title
    end

    # Apply site specific filters
    if site = @filters[link[:site]]
      if filters = site[link[:type]]
        if filters.is_a?( Array)
          filters.each do |filter|
            status, valid, title = apply_filter( filter, link, body, title)
            return status, valid, title unless status && valid
          end
        else
          status, valid, title = apply_filter( filters, link, body, title)
        end
      end
    end

    return status, valid, title
  end

  def get_title( page)
    if m = /<title>([^<]*)<\/title>/im.match( page)
      title = m[1].gsub( /\s/, ' ')
      title.force_encoding( 'UTF-8')
      title.encode!( 'US-ASCII',
                     :replace           => ' ',
                     :invalid           => :replace,
                     :undef             => :replace,
                     :universal_newline => true)
      title.strip.gsub( '  ', ' ')
    else
      ''
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

  def oldest( n)
    verified, unverified = [], []
    @database.select( 'link') do |rec|

      # Unbound records not priority
      bind = @database.get( 'bind', :url, rec[:url])
      unbound = (bind[0] && (bind[0][:id] == -1))

      if unbound || (rec[:valid] && (rec[:valid] == 'Y'))
        verified << rec
      else
        unverified << rec
      end
    end

    unverified.shuffle!
    verified.sort_by! {|rec| rec[:timestamp] ? rec[:timestamp].to_i : 0}
    links = unverified + verified
    links = links[0...n] if links.size > n
    links.each {|rec| yield rec}
  end

  def update_link( link)
    @database.start_transaction
    @database.delete( 'link', :url, link[:url])
    @database.insert( 'link', link)
    @database.end_transaction
  end

  def verify_page( link, cache)
    sleep 10
    status, response = http_get( link[:url])
    return unless status

    status, valid, title = get_details( link, response.body)
    return unless status && (title.strip != '')

    t = Time.now.to_i
    File.open( cache + "/#{t}.html", 'w') {|io| io.print response.body}

    link[:title]     = title.strip
    link[:timestamp] = t
    link[:valid]     = valid ? 'Y' : 'N'

    update_link( link)
  end
end

vl = VerifyLinks.new( ARGV[0])
vl.oldest( ARGV[1].to_i) do |link|
  puts "... Verifying #{link[:url]}"
  vl.verify_page( link, ARGV[2])
end

puts "End of verifying"