require 'net/http'
require 'net/https'
require 'uri'
require_relative '../pagoda'

$pagoda = Pagoda.release( ARGV[0])

def links
  $pagoda.links do |link|
    'MobyGames' == link.site
  end.each {|link| yield link}
end

to_correct = 0
links do |link|
  if game = link.collation
    if m = /\((\d\d\d\d)\)/.match( link.title)
      if game.year.nil? || (game.year > m[1].to_i)
        rec = $pagoda.get( 'game', :id, game.id)[0]
        p [link.title, game.year]
        $pagoda.start_transaction
        $pagoda.delete'game', :id, game.id
        rec[:year] = m[1].to_i
        $pagoda.insert 'game', rec
        $pagoda.end_transaction
        to_correct += 1
      end
    end
  end
end

puts "*** #{to_correct} wrong years"

