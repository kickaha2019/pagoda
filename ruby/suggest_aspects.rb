require 'yaml'
require_relative 'pagoda'

class SuggestAspects
  def initialize( dir, cache)
    @pagoda = Pagoda.new( dir)
    @cache  = cache
    @rules  = YAML.load( IO.read( dir + '/aspect_suggest.yaml'))
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

  def match( game, rule)
    aspects = game.aspects
    set     = true
    rule['aspect'].split(',').each do |a|
      set = false unless aspects.include?( a.strip)
    end
    return if set

    @pagoda.get( 'bind', :id, game.id).each do |bind|
      @pagoda.get( 'link', :url, bind[:url]).each do |link|
        next if link[:timestamp].nil?
        next if /\)$/ =~ link[:site]
        page = IO.read( "#{@cache}/verified/#{link[:timestamp]}.html")
        if rule['match'].is_a?( String)
          text = scan( page, rule['match'])
        else
          rule['match'].each do |re|
            text = scan( page, re) unless text
          end
        end
        if text
          yield rule['aspect'], text, link[:timestamp]
        end
      end
    end
  end

  def record( game, rule, aspects, text, cache)
    #p ['record', game.name, rule, aspects, text, cache]
    @pagoda.start_transaction
    @pagoda.delete( 'aspect_suggest', :game, game.id)
    @pagoda.insert( 'aspect_suggest',
                    {:game      => game.id,
                             :aspect    => aspects,
                             :rule      => rule,
                             :cache     => cache,
                             :text      => text,
                             :timestamp => Time.now.to_i})
    @pagoda.end_transaction
  end

  def scan( page, regex)
    scanner = StringScanner.new( page)
    unless scanner.skip_until( Regexp.new(regex, Regexp::MULTILINE)).nil?
      pos = scanner.pointer
      from = pos - 500
      from = 0 if from < 0
      to = pos + 500
      to = page.size - 1 if to >= page.size
      text = page[from..to].gsub( "\n", ' ').gsub( '&nbsp;', ' ').gsub( /\s+/, ' ')
      text = text.gsub( /(^|<)[^>]*>/, ' ')
      text = text.gsub( /<[^>]*(>|$)/, ' ')
      return text
    end
    nil
  end

  def suggest( game, last_rule)
    ((last_rule+1)...(@rules.size)).each do |i|
      match( game, @rules[i]) do |aspects, text, cache|
        yield i, aspects, text, cache
        return
      end
    end

    (0..last_rule).each do |i|
      match( game, @rules[i]) do |aspects, text, cache|
        yield i, aspects, text, cache
        return
      end
    end
  end
end

sa = SuggestAspects.new( ARGV[0], ARGV[1])
suggested = 0
sa.games do |game, last_rule|
  #p ['games1', game.name, game.id, last_rule]
  sa.suggest( game, last_rule) do |rule, aspects, text, cache|
    sa.record( game, rule, aspects, text, cache)
    suggested += 1
    exit if suggested >= ARGV[2].to_i
  end
end