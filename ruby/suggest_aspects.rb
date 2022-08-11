require 'yaml'
require_relative 'common'
require_relative 'pagoda'

class SuggestAspects
  include Common
  attr_reader :tagged
  
  def initialize( dir, cache)
    @pagoda  = Pagoda.new( dir)
    @cache   = cache
    @aspects = YAML.load( IO.read( dir + '/aspects.yaml'))
    @tagged  = 0
    @errors  = []
  end

  def games( name)
    if name && (name != '')
      yield @pagoda.game( name)
      return
    end
    map = {}
    @pagoda.games {|g| map[g.id] = 0}
    @pagoda.select( 'aspect_suggest') do |suggest|
      map[suggest[:game]] = suggest[:timestamp] unless suggest[:timestamp].nil?
    end
    list = map.keys.collect {|k| [k, map[k]]}
    list.sort_by {|e| e[1]}.each do |e|
      g = @pagoda.game(e[0])
      yield g unless g.group_name
    end
  end

  def get_page( site_name, timestamp)
    page = IO.read( "#{@cache}/verified/#{timestamp}.html")

    site = @pagoda.get_site_handler( site_name)
    #p ['get_page1', site_name, timestamp]
    page = site.get_game_description( page)

    page = page.gsub( "\n", ' ').gsub( '&nbsp;', ' ').gsub( '&amp;', '&').gsub( /\s+/, ' ')
    page = page.gsub( /(^|<)[^>]*>/m, ' ')
    page = page.gsub( /<[^>]*(>|$)/m, ' ')

    page
  end

  def match( game, aspect_name, page)
    #p ['match1', game.name]
    aspects = game.aspects
    return unless aspects[aspect_name].nil?

    matches = @aspects[aspect_name]['match']
    matches = [matches] if matches.is_a?( String)
    ignores = @aspects[aspect_name]['ignore']
    ignores = [ignores] if ignores.is_a?( String)
    ignores = [] if ignores.nil?

    text = nil
    matches.each do |m|
      re = Regexp.new( m, Regexp::IGNORECASE | Regexp::MULTILINE)
      text = scan( page, re, ignores) unless text
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

  def report_errors
    @errors.uniq.each do |error|
      puts "*** #{error}"
    end
  end

  def scan( page, regex, ignores)
    ignored_page = page
    ignores.each do |ignore|
      re = Regexp.new( ignore, Regexp::IGNORECASE)
      ignored_page = ignored_page.gsub( re) do |match|
        "                                        "[0...(match.size)]
      end
    end

    scanner = StringScanner.new( ignored_page)
    if scanner.skip_until( regex)
      pos = scanner.pointer
      from = pos - 200  - scanner.matched_size
      from = 0 if from < 0
      to = from + 400
      to = page.size - 1 if to >= page.size
      text = h(page[from...(pos - scanner.matched_size)]) +
             '<font color="red"><b>' +
             h(page[(pos - scanner.matched_size)...pos]) +
             '</b></font>' +
             h(page[pos..to])
      return text
    end

    nil
  end

  def suggest( game, aspect_arg, site_arg)
    possible_aspects = []
    if aspect_arg
      possible_aspects << aspect_arg
    else
      possible_aspects = @aspects.keys.select {|k| @aspects[k]['match']}.shuffle
    end

    @pagoda.get( 'bind', :id, game.id).each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next if link[:timestamp].nil?
        next if site_arg && (link[:site] != site_arg)
        tag_aspects( link[:site], link[:timestamp], game)
      end
    end

    @pagoda.get( 'bind', :id, game.id).shuffle.each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next if link[:timestamp].nil?
        next if site_arg && (link[:site] != site_arg)

        page = get_page( link[:site], link[:timestamp])

        possible_aspects.each do |aspect_name|
          match( game, aspect_name, page) do |text|
            return aspect_name, text, link[:timestamp], link[:site]
          end
        end
      end
    end

    return '', '', 0, ''
  end

  def tag_aspects( site_name, timestamp, game)
    aspects = game.aspects
    page = IO.read( "#{@cache}/verified/#{timestamp}.html")
    site = @pagoda.get_site_handler( site_name)

    site.tag_aspects( @pagoda, page) do |aspect|
      unless aspects[aspect]
        @tagged += 1
        @pagoda.start_transaction
        @pagoda.insert( 'aspect', {:id => game.id, :aspect => aspect, :flag => 'Y'})
        @pagoda.end_transaction
      end
    end
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
# puts sa.get_page( 'MobyGames', 1651009354)
# raise 'Testing'

suggested = scanned = 0
to_scan = ARGV[2].to_i

puts "... Suggesting aspects"
sa.games( ARGV[3]) do |game|
  #p ['games1', game.name, game.id, last_rule]
  suggested += 1 if sa.record( game, * sa.suggest( game, ARGV[4], ARGV[5]))
  scanned += 1
  break if scanned >= to_scan
end

puts "... Suggested #{suggested} aspects"
puts "... Tagged #{sa.tagged} aspects"

sa.report_errors