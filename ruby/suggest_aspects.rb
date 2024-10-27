require 'yaml'
require_relative 'common'
require_relative 'pagoda'

class SuggestAspects
  include Common
  attr_reader :tagged
  NC = '[^0-9A-Z]'

  def initialize( dir, cache)
    @pagoda  = Pagoda.new( dir, cache)
    @aspects = YAML.load( IO.read( dir + '/aspects.yaml'))
    @tagged  = 0
    @errors  = []
  end

  def find_matches( page, matches)
    page  = ' ' + page + ' '
    found = false

    matches.each do |match|
      re = Regexp.new( NC + match.gsub( ' ', NC + '+') + NC, Regexp::IGNORECASE)
      page.sub!( re) do |m|
        found = true
        "&&&#{m}&&&"
      end

      if found
        els = page.split( '&&&') # '<font color="red"><b>')
        els[0] = els[0][-100..-1] if els[0].size > 100
        els[2] = els[2][0..99] if els[2].size > 100
        return els[0] + '<font color="red"><b>' + els[1] + '</b></font>' + els[2]
      end
    end

    nil
  end

  def games( name, aspect)
    if name && (name != '')
      g = @pagoda.game( name)
      raise "*** Unknown id: #{name}" unless g
      yield g
      return
    end
    map = {}
    @pagoda.games {|g| map[g.id] = 0}

    @pagoda.select( 'aspect_suggest') do |suggest|
      map[suggest[:game]] = suggest[:timestamp] if suggest[:timestamp] && (suggest[:timestamp] > 100)
    end

    list = map.keys.collect {|k| [k, map[k]]}
    list.sort_by {|e| e[1]}.each do |e|
      g = @pagoda.game(e[0])

      if aspect && (aspect != '')
        next if g.aspects.has_key?( aspect)
      end

      yield g unless g.group_name
    end
  end

  def get_page( site_name, timestamp)
    page = IO.read( @pagoda.cache_path( timestamp))

    site = @pagoda.get_site_handler( site_name)
    #p ['get_page1', site_name, timestamp]
    page = site.get_game_description( page)

    page = page.gsub( /<style.*?<\/style>/mi, '')
    page = page.gsub( "\n", ' ').gsub( '&nbsp;', ' ').gsub( '&amp;', '&').gsub( /\s+/, ' ').gsub( '&#x2F;', ' ')
    page = page.gsub( /(^|<)[^>]*>/m, ' ')
    page = page.gsub( /<[^>]*(>|$)/m, ' ')

    page
  end

  def match( game, aspect_name, timestamp, page)
    #p ['match1', game.name]
    aspects = game.aspects
    return unless aspects[aspect_name].nil?

    ref = "suggest_aspects:#{aspect_name}-#{timestamp}"
    return if @pagoda.has?( 'visited', :key, ref)

    matches = @aspects[aspect_name]['match']
    matches = [matches] if matches.is_a?( String)
    ignores = @aspects[aspect_name]['ignore']
    ignores = [ignores] if ignores.is_a?( String)
    ignores = [] if ignores.nil?

    page = remove_ignores( page, ignores)
    if found = find_matches( page, matches)
      yield ref, found
    end
  end

  def record( game, aspects, text, cache, ref, site)
    #p ['record', game.name, aspects, link[:timestamp]text, cache, site]
    @pagoda.start_transaction
    @pagoda.delete( 'aspect_suggest', :game, game.id)
    @pagoda.insert( 'aspect_suggest',
                    {:game      => game.id,
                             :aspect    => aspects,
                             :cache     => cache,
                             :text      => text,
                             :site      => site,
                             :visit     => ref,
                             :timestamp => Time.now.to_i})
    @pagoda.end_transaction
    cache > 0
  end

  def remove_ignores( page, ignores)
    page     = ' ' + page + ' '
    ignores.each do |ignore|
      re = Regexp.new( NC + ignore.gsub( ' ', NC + '+') + NC, Regexp::IGNORECASE)
      page = page.gsub( re, ' ')
    end
    page
  end

  def report_errors
    @errors.uniq.each do |error|
      puts "*** #{error}"
    end
  end

  # def scan( text, matches, ignores)
  #   reduced = text.gsub( /[^A-Z0-9]/i, ' ').gsub( '  ', ' ').gsub( '  ', ' ').downcase
  #
  #   ignores.each do |ignore|
  #     reduced = reduced.gsub( ' ' + ignore.downcase + ' ', ' ')
  #   end
  #
  #   matches.each do |match|
  #     re = Regexp.new( ' ' + match + ' ', Regexp::IGNORECASE | Regexp::MULTILINE)
  #     if re =~ reduced
  #       return match
  #     end
  #   end
  #
  #   false
  # end

  def suggest( game, aspect_arg, site_arg)
    possible_aspects = []
    if aspect_arg && (aspect_arg != '')
      possible_aspects << aspect_arg
    else
      possible_aspects = @aspects.keys.select {|k| @aspects[k]['match']}.shuffle
    end

    @pagoda.get( 'bind', :id, game.id).each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next unless link[:timestamp] && (link[:timestamp] > 100)
        next if site_arg && (link[:site] != site_arg)
        tag_aspects( link, game)
      end
    end

    @pagoda.get( 'bind', :id, game.id).shuffle.each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next unless link[:timestamp] && (link[:timestamp] > 100)
        next if site_arg && (link[:site] != site_arg)

        page = get_page( link[:site], link[:timestamp])

        possible_aspects.each do |aspect_name|
          match( game, aspect_name, link[:timestamp], page) do |ref, text|
            return aspect_name, text, link[:timestamp], ref, link[:site]
          end
        end
      end
    end

    return '', '', 0, '', ''
  end

  def tag_aspects( link, game)
    aspects = game.aspects
    page = IO.read( @pagoda.cache_path( link[:timestamp]))
    site = @pagoda.get_site_handler( link[:site])

    site.get_aspects(@pagoda, link[:url], page) do |aspect|
      unless aspects.has_key?(aspect)
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
sa.games( ARGV[3], ARGV[4]) do |game|
  #p ['games1', game.name, game.id]
  suggested += 1 if sa.record( game, * sa.suggest( game, ARGV[4], ARGV[5]))
  scanned += 1
  break if scanned >= to_scan
end

puts "... Suggested #{suggested} aspects"
puts "... Tagged #{sa.tagged} aspects"

sa.report_errors