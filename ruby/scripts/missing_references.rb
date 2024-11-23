require 'net/http'
require 'net/https'
require 'uri'
require_relative '../pagoda'

class MissingReferences
  def initialize(args)
    @pagoda = Pagoda.release(args[0], args[1])
    @from   = args[2].to_i
    @to     = args[3].to_i
    @file   = File.open(args[4],'w')
    @file.puts <<HEADER
<html>
<head>
<style>
    body {display: flex; flex-direction: column; align-items: center;}
    table {border-collapse: collapse; margin-left: auto; margin-right: auto; font-size: 24px; margin-bottom: 20px}
    th, td {border: 1px solid black; border-collapse: collapse; padding: 5px}
</style>
</head>
<body>
<table>
<tr><th>Game</th><th>Year</th><</tr>
HEADER
  end

  def list_game(game)
    @file.puts <<LINK
<tr><td>
<a target="_blank" href="http://localhost:4567/game/#{game.id}">#{game.name}</a>
</td><td>#{game.year}</td></tr>
LINK
  end

  def close
    @file.puts <<FOOTER
</body>
</html>
FOOTER
    @file.close
  end

  def games
    (@from..@to).each do |id|
      if g = @pagoda.game(id)
        next if g.aspects['Lost'] || g.group?
        yield g
      end
    end
  end

  def has_references( game)
    has = false
    @pagoda.get( 'bind', :id, game.id).each do |rec|
      if link = @pagoda.link( rec[:url])
        if ['IGDB', 'MobyGames', 'Steam', 'GOG'].include?( link.site)
          has = true
        end
      end
    end
    has
  end
end

cly = MissingReferences.new ARGV
cly.games do |game|
  unless cly.has_references(game)
    cly.list_game(game)
  end
end
cly.close
