#
# Gather child links
#
# Command line
#   Pagoda database directory
#   Cache directory
#   URL to gather links from OR #games to scan
#

require_relative 'pagoda'
require_relative 'common'

class GatherChildLinks
  include Common

  def initialize( dir, cache)
    @pagoda = Pagoda.new( dir)
    @cache  = cache
  end

  def oldest_caches( width)
    games = []
    @pagoda.games do |game|
      path = "#{@cache}/child_links/#{game.id}.txt"
      if File.exist?( path)
        games << [game.id, File.mtime( path).to_i]
      else
        games << [game.id, 0]
      end
    end

    games = games.sort_by {|rec| rec[1]}
    games[0...width].each do |game_rec|
      @pagoda.get( 'bind', :id, game_rec[0]).each do |bind_rec|
        link_rec = @pagoda.get( 'link', :url, bind_rec[:url])[0]
        next unless link_rec[:valid]
        yield( game_rec[0], link_rec[:site], link_rec[:url], IO.read( @cache + "/verified/#{link_rec[:timestamp]}.html"))
      end
    end
  end

  def save_links( game_id, links)
    File.open( "#{@cache}/child_links/#{game_id}.txt", 'w') do |io|
      links.each {|link| io.puts link}
    end
  end

  def scan( site_name, url, page)
    site = get_site_class( site_name).new
    page.force_encoding( 'UTF-8')
    page.encode!( 'US-ASCII',
                  :replace           => ' ',
                  :invalid           => :replace,
                  :undef             => :replace,
                  :universal_newline => true)

    links = []
    page.scan( /<a([^>]*)>([^<]*)</im) do |anchor|
      if m = /href\s*=\s*"([^"]*)"/i.match( anchor[0])
        next if /\.(jpg|jpeg|png|gif)$/i =~ m[1]
        #p [site_name, anchor[1], m[1]]
        site.check_child_link( url, anchor[1], m[1]) do |href|
          links << href
        end
      end
    end

    links.uniq
  end
end

gcl = GatherChildLinks.new( ARGV[0], ARGV[1])
if /^http/ =~ ARGV[3]
  links = gcl.scan( ARGV[2], ARGV[3], gcl.http_get( ARGV[3]))
  links.each {|link| puts "... #{link}"}
  puts "... #{links.size} found"
else
  puts "... Gathering child links"
  count = 0
  gcl.detect_hang
  gcl.oldest_caches( ARGV[2].to_i) do |game_id, site, url, page|
    #p ['DEBUG3', game_id, url]
    links = gcl.scan( site, url, page)
    gcl.save_links( game_id, links)
    count += links.size
  end
  puts "... Gathered #{count} child links"
end