require 'net/http'
require 'net/https'
require 'uri'
require_relative '../pagoda'

class CheckLinkYears
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
<tr><th>Game</th><th>Year</th><th>Link</th><th>Year</th></tr>
HEADER
  end

  def check_years(game,link)
    return if link.timestamp <= 100
    site = @pagoda.get_site_handler(link.site)
    # return if site.class == DefaultSite
    digest = @pagoda.cache_digest( link.timestamp)
    # unless page != ''
    #   puts "*** Missing file for #{link.site} #{link.url}"
    #   return
    # end
    # details = {}
    # site.get_game_details(link.url,page,details)
    if digest['year']
      year, tolerance = details[:year], 1
    elsif digest['link_year']
      year, tolerance = digest['link_year'], site.year_tolerance
    else
      return
    end
    okay, year = game.year, year.to_i
    okay = false if okay && (year < game.year)
    okay = false if okay && (year > (tolerance + game.year))

    unless okay
      @file.puts <<LINK
<tr><td>
<a target="_blank" href="http://localhost:4567/game/#{game.id}">#{game.name}</a>
</td><td>#{game.year}</td><td>#{link.site}</td><td>#{year}</td></tr>
LINK
    end
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
        yield g
      end
    end
  end

  def links( game)
    @pagoda.get( 'bind', :id, game.id).each do |rec|
      if link = @pagoda.link( rec[:url])
        yield link
      end
    end
  end
end

cly = CheckLinkYears.new ARGV
cly.games do |game|
  cly.links(game) do |link|
    cly.check_years(game,link)
  end
end
cly.close

