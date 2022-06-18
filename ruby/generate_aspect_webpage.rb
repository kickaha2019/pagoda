require 'erb'
require_relative 'pagoda'

class WebsiteFiltersPage
  class Playable
    attr_reader :name, :year, :url, :steam, :gog
    def initialize( owner, name, year)
      @owner  = owner
      @name   = name
      @year   = year
      @url    = nil
      @flags  = [0] * 64
      @steam  = nil
      @gog    = nil
    end

    def flags( from, to)
      bits = 0
      (0..(to-from)).each do |i|
        bits = bits * 2 + @flags[to-i]
      end
      bits
    end

    def record( site, url, page)
      if site.name == 'GOG'
        @gog = url.split('/')[-1] unless @gog
      end

      if site.name == 'Steam'
        @steam = url.split('/')[-1] unless @steam
      end

      site.get_derived_aspects( page) do |aspect|
        record_aspect( aspect)
      end
    end

    def record_aspect( aspect)
      @flags[ @owner.aspect_index( aspect)] = 1
    end

    def record_url( url)
      @url = url unless @url
    end
  end

  def initialize( dir, cache, templates)
    @pagoda    = Pagoda.new( dir)
    @cache     = cache
    @aspects   = YAML.load( IO.read( dir + '/aspects.yaml'))
    @templates = templates

    seen = {}
    @aspects.each_pair do |name, info|
      next unless info['index']
      raise "Duplicate index for aspect #{name}" if seen[info['index'].to_i]
      seen[info['index'].to_i] = true
    end

    @aspects.each_pair do |name, info|
      unless info['index']
        free = -1
        (0..100).each do |i|
          unless seen[i]
            free = i
            break
          end
        end
        raise "No index for aspect #{name} suggest #{free}"
      end
    end
  end

  def aspect_index( aspect)
    @aspects[aspect]['index']
  end

  def aspect_name_indexes
    @aspects.each_pair do |name, info|
      yield name, info['index']
    end
  end

  def games
    list = []
    @pagoda.game( 0)   # Force index to be created
    @pagoda.games do |game|
      next if game.is_group == 'Y'
      playable = Playable.new( self, game.name, game.year)
      seen = {}
      get_game_info( game, playable, seen)
      list << playable
    end

    p [list.size]
    list.sort_by! {|g| g.name}
  end

  def get_game_info( game, playable, seen)
    return if seen[ game.id]

    game.aspects.each_pair do |aspect, flag|
      playable.record_aspect( aspect) if flag
    end

    game.links do |link|
      next unless link.valid?
      if (link.site == 'Website') && (link.type == 'Official')
        playable.record_url( link.url)
      elsif link.type == 'Store'
        site = @pagoda.get_site_handler( link.site)
        page = IO.read( "#{@cache}/#{link.timestamp}.html")
        playable.record( site, link.url, page)
      end
    end

    seen[game.id] = true
    if game.group_id && (parent = @pagoda.game( game.group_id))
      get_game_info( parent, playable, seen)
    end
  end

  def generate( output_dir)
    aspects    = @aspects
    containers = ['include', 'unused', 'exclude']

    aspects_section = template( 'aspects').result( binding)
    filters_section = template( 'filters').result( binding)
    welcome_section = template( 'welcome').result( binding)

    File.open( output_dir + '/index.html', 'w') do |io|
      io.print template('index').result( binding)
    end

    File.open( output_dir + '/games.js', 'w') do |io|
      io.puts "var games = ["
      games.each do |game|
        io.print "['#{game.name.gsub( "'", "\\'")}'"
        io.print ",'#{game.url}'"
        io.print ",#{game.year}"
        io.print ",#{game.flags(0,31)}"
        io.print ",#{game.flags(32,63)}"
        io.print ",'#{game.steam}'"
        io.puts  ",'#{game.gog}']"
      end
      io.puts "];"
    end

    # File.open( output_dir + '/filters.html', 'w') do |io|
    #   aspects    = @aspects
    #   containers = ['include', 'unused', 'exclude']
    #   io.print @filters_template.result( binding)
    # end
  end

  def template( name)
    ERB.new( IO.read( @templates + '/' + name + '.erb'))
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0], ARGV[1], ARGV[2])
wfp.generate( ARGV[3])
