require 'net/http'
require 'net/https'
require 'uri'
require_relative 'database'
require_relative 'pagoda'

#db = Database.new( ARGV[0])
$pagoda = Pagoda.new( ARGV[0])

def links
  $pagoda.links do |link|
    /^https:\/\/tap-repeatedly.com/ =~ link.url
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
  url = 'https://web.archive.org/web/20221231071432/' + link.url
  resp = http_get_response( url)

  if resp['Location']
    link.delete
    $pagoda.add_link( link.site, link.type, link.title, resp['Location'], 'Y')
    p [link.title, link.url]
  end
end

# url = nil
# IO.readlines( ARGV[0] + '/../temp/bill_reviews.html').each do |line|
#   if m = /<a href="(.*\.htm)">/.match( line)
#     url = 'https://web.archive.org/web/20010220070325/http://www.mrbillsadventureland.com/reviews/' + m[1]
#   end
#
#   if m = /<a href="#/.match( line)
#     url = nil
#   end
#
#   if m = /<b>(.*)<\/b>/.match( line)
#     if url
#       if known?( db, m[1])
#         url = nil
#         next
#       end
#
#       p [url, m[1]]
#
#       resp = http_get_response( url)
#       p [resp.code, resp['Location']]
#       exit 1
#
#       if resp['Location']
#         url = resp['Location']
#       end
#       #p url
#       #exit 0
#
#       # File.open( ARGV[0] + '/../temp/bill_frame.html', 'w') do |io|
#       #   io.print resp.body
#       # end
#       db.start_transaction
#       db.insert( 'link', {:site => "Mr. Bill's Adventureland",
#                           :type => 'Review',
#                           :title => m[1],
#                           :url => url,
#                           :timestamp => 0,
#                           :static     => 'Y',
#                           :orig_title => m[1]})
#       db.end_transaction
#
#       url = nil
#     end
#   end
# end
