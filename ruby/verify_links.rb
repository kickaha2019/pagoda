require 'net/http'
require 'uri'
require 'openssl'
require_relative 'database'

class VerifyLinks
  def initialize( dir)
    @database = Database.new( dir)
  end

  def check_title( link, page)
    title = get_title( page)
    unless link[:title].nil? || (link[:title] == title)
      link[:verified] = 'N'
    end
    link[:title] = title
  end

  def get_page( link, cache)
    sleep 10
    status, response = http_get( link[:url])
    return nil unless status

    page = response.body
    t = Time.now.to_i
    File.open( cache + "/#{t}.html", 'w') {|io| io.print page}
    link[:timestamp] = t

    page
  end

  def get_title( page)
    if m = /<title>([^<]*)<\/title>/im.match( page)
      m[1]
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
    links = []
    @database.select( 'link') {|rec| links << rec}
    links.sort_by! {|rec| rec[:verified] ? rec[:verified].to_i : 0}
    links = links[0...n] if links.size > n
    links.each {|rec| yield rec}
  end

  def update_link( link)
    @database.start_transaction
    @database.delete( 'link', :url, link[:url])
    @database.insert( 'link', link)
    @database.end_transaction
  end
end

vl = VerifyLinks.new( ARGV[0])
vl.oldest( ARGV[1].to_i) do |link|
  puts "... Verifying #{link[:url]}"
  if page = vl.get_page( link, ARGV[2])
    vl.check_title( link, page)
  else
    link[:verified] = 'N'
  end

  vl.update_link( link)
end

puts "End of verifying"