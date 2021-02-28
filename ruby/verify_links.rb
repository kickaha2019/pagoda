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

  def get_details( link, body)
    filter = 'pass'
    filter_args = []

    if site = @filters[link[:site]]
      if type = site[link[:type]]
        if type.is_a?( String)
          filter = type
        else
          raise 'Unexpected filters' if type.size != 1
          filter = type.keys[0]
          filter_args = type.values[0]
          filter_args = [filter_args] unless filter_args.is_a?( Array)
        end
      end
    end

    status, valid, title = send( ('filter_' + filter).to_sym, link, body, * filter_args)
    return status, valid, title
  end

  def filter_ios_store( link, body)
    return true, true, get_title( body)
  end

  def filter_pass( link, body)
    return true, true, get_title( body)
  end

  def filter_suffix( link, body, suffix)
    i = (title = get_title( body)).index( suffix)
    if i && (i > 0)
      return true, true, title[0...i]
    else
      return false, false, ''
    end
  end

  def get_title( page)
    if m = /<title>([^<]*)<\/title>/im.match( page)
      title = m[1].gsub( /\s/, ' ')
      title.force_encoding( 'UTF-8')
      title.encode( 'US-ASCII',
                    :invalid => :replace,
                    :undef => :replace,
                    :universal_newline => true)
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
      if rec[:valid] && (rec[:valid] == 'Y')
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