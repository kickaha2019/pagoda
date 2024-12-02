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
    # site   = @pagoda.get_site_handler( link.site)
    # rec[:title] = site.get_title( link.url, body, link.type)
    rec[:title] = body.is_a?(String) ? nil : body['title']

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

    true
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
      elsif link.unreleased?
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
      (0..2).each do
        links << bound.pop unless bound.empty?
      end
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

    site = @pagoda.get_site_handler( link.site)
    status, body = site.digest_link(@pagoda, link.url)
    body = status ? force_ascii(body) : body

    if status && (comment = site.validate_page(link.url, body))
      status = false
      body   = comment
    end

    rec = {title:'',
           timestamp:Time.now.to_i,
           unreleased:(body['unreleased'] ? true : false),
           valid:true,
           changed: false}

    # Get year if possible for link
    if status && body['year']
      rec[:year] = body['year']
    end

    # Get details
    if status
      p ['verify_page3', status, rec] if debug
      status = get_details( link, body, rec)
      p ['verify_page4', status, rec] if debug
    else
      rec[:valid]   = false
      rec[:title]   = link.title
      rec[:comment] = body
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
