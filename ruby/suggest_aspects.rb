require 'yaml'
require_relative 'common'
require_relative 'pagoda'

class SuggestAspects
  include Common

  def initialize( dir, cache)
    @pagoda = Pagoda.new( dir)
    @cache  = cache
    defn    = YAML.load( IO.read( dir + '/aspect_suggest.yaml'))
    @rules  = defn['rules']
  end

  def games
    map = {}
    @pagoda.games {|g| map[g.id] = [0,-1]}
    @pagoda.select( 'aspect_suggest') do |suggest|
      map[suggest[:game]] = [suggest[:timestamp], suggest[:rule]] unless suggest[:timestamp].nil?
    end
    list = map.keys.collect {|k| [k, map[k][0], map[k][1]]}
    list.sort_by {|e| e[1]}.each {|e| yield @pagoda.game(e[0]), e[2]}
  end

  def get_page( site_name, timestamp)
    page = IO.read( "#{@cache}/verified/#{timestamp}.html")

    site = get_site_class( site_name).new
    #p ['get_page1', site_name, timestamp]
    page = site.get_game_description( page)

    page = page.gsub( "\n", ' ').gsub( '&nbsp;', ' ').gsub( '&amp;', '&').gsub( /\s+/, ' ')
    page = page.gsub( /(^|<)[^>]*>/m, ' ')
    page = page.gsub( /<[^>]*(>|$)/m, ' ')

    page
  end

  def match( game, rule, page)
    #p ['match1', game.name]
    aspects = game.aspects
    set     = true
    rule['aspect'].split(',').each do |a|
      set = false if aspects[a.strip].nil?
    end
    return if set

    if rule['match'].is_a?( String)
      text = scan( page, rule['match'])
    else
      rule['match'].shuffle.each do |re|
        text = scan( page, re) unless text
      end
    end

    if text
      yield text
    end
  end

  def record( game, aspects, text, cache, site)
    #p ['record', game.name, aspects, text, cache, site]
    @pagoda.start_transaction
    @pagoda.delete( 'aspect_suggest', :game, game.id)
    @pagoda.insert( 'aspect_suggest',
                    {:game      => game.id,
                             :aspect    => aspects,
                             :cache     => cache,
                             :text      => text,
                             :site      => site,
                             :timestamp => Time.now.to_i})
    @pagoda.end_transaction
    cache > 0
  end

  def scan( page, regex)
    scanner = StringScanner.new( page)
    unless scanner.skip_until( Regexp.new(regex, Regexp::MULTILINE)).nil?
      pos = scanner.pointer
      from = pos - 200
      from = 0 if from < 0
      to = pos + 200
      to = page.size - 1 if to >= page.size
      text = page[from..to]
      return text
    end
    nil
  end

  def suggest( game)
    @pagoda.get( 'bind', :id, game.id).shuffle.each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next if link[:timestamp].nil?
        next if /\)$/ =~ link[:site]
        page = get_page( link[:site], link[:timestamp])

        @rules.shuffle.each do |rule|
          match( game, rule, page) do |text|
            return rule['aspect'], text, link[:timestamp], link[:site]
          end
        end
      end
    end

    return '', '', 0, ''
  end
end

sa = SuggestAspects.new( ARGV[0], ARGV[1])

#puts sa.get_page( 'GOG', 1646346107)
#puts sa.get_page( 'Steam', 1647566107)
#puts sa.get_page( 'Apple', 1646698190)
#puts sa.get_page( 'Google Play', 1646606091)
#puts sa.get_page( 'Adventure Gamers', 1647813039)
#puts sa.get_page( 'Website', 1647727550)
#puts sa.get_page( 'TouchArcade', 1646962827)
#raise 'Testing'

suggested = scanned = 0
puts "... Suggesting aspects"
sa.games do |game, last_rule|
  #p ['games1', game.name, game.id, last_rule]
  suggested += 1 if sa.record( game, * sa.suggest( game))
  scanned += 1
  break if scanned >= ARGV[2].to_i
end
puts "... Suggested #{suggested} aspects"