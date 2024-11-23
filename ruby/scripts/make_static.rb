require 'net/http'
require 'net/https'
require 'uri'
require_relative '../database'
require_relative 'pagoda'

#db = Database.new( ARGV[0])
$pagoda = Pagoda.release( ARGV[0])

def links
  $pagoda.links do |link|
    /www.pcgameswalkthroughs.nl/ =~ link.url
  end.each {|link| yield link}
end

def known?( db, game)
  db.get( 'link', :site, "Mr. Bill's Adventureland") do |rec|
    return true if rec[:orig_title] == game
  end
  false
end

def http_get_response( url)
  uri = URI.parse( url)

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Accept']          = 'text/html,application/xhtml+xml,application/xml'
  request['Accept-Language'] = 'en-gb'
  request['User-Agent']      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

  use_ssl     = uri.scheme == 'https'
  verify_mode = OpenSSL::SSL::VERIFY_NONE

  Net::HTTP.start( uri.hostname, uri.port, :use_ssl => use_ssl, :verify_mode => verify_mode) {|http|
    http.request( request)
  }
end

links do |link|
  binds = $pagoda.get( 'bind', :url, link.url)
  bind_id = binds.empty? ? nil : binds[0][:id]
  link.delete
  $pagoda.add_link( link.site, link.type, link.title, link.url, 'Y')
  unless bind_id.nil?
    link.bind( bind_id)
  end
  p [link.title, link.url]
end

