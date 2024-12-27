require 'net/http'
require 'uri'
require 'openssl'
require 'yaml'

require_relative 'pagoda'
require_relative 'common'

class Verifier
  include Common

  def initialize(pagoda)
    @pagoda   = pagoda
  end

  def get_details( link, body, rec)
    rec[:title] = body['title']

    # 404 errors
    if /^IIS.*404.*Not Found$/ =~ rec[:title]
      return rec[:title]
    end

    # Server errors
    if /Internal Server Error/i =~ rec[:title]
      return rec[:title]
    end

    nil
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

      if (link.status == 'Invalid') || link.comment
        #puts "Dubious: #{link.url} / #{link.comment}"
        must << link
      elsif /free/i =~ link.status
        loose << link
      elsif link.status == 'Ignored'
        loose << link
      elsif link.status == 'Rejected'
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
      (0..1).each do |_|
        links << loose.pop unless loose.empty?
      end
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

    site = @pagoda.get_site_handler( link.site)
    status, delete, body = site.digest_link(@pagoda, link.url)
    p ['verify_page2', status, delete] if debug

    if delete
      link.delete
      return
    end

    unless status
      link.complain body
      return
    end

    body = force_ascii(body)
    if comment = site.validate_page(link.url, body)
      link.complain comment
      return
    end

    rec = {title:'',
           timestamp:Time.now.to_i,
           reject:(body['unreleased'] ? true : false),
           valid:true,
           comment: nil}

    # Get year if possible for link
    rec[:year] = body['year'] if status && body['year']

    # Get details
    p ['verify_page3', status, rec] if debug
    if comment = get_details( link, body, rec)
      link.complain comment
      return
    end
    p ['verify_page4', status, rec] if debug

    @pagoda.update_link(link, rec, body, debug)
    if game = link.collation
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
end
