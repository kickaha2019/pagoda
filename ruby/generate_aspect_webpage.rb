require 'erb'
require_relative 'pagoda'

class WebsiteFiltersPage
  class Playable
    attr_reader :id, :name, :year, :steam, :gog
    def initialize( owner, id, name, year)
      @owner   = owner
      @id      = id
      @name    = name
      @year    = year
      @flags   = [0] * 64
      @steam   = nil
      @gog     = nil
    end

    def flags( from, to)
      bits = 0
      (0..(to-from)).each do |i|
        bits = bits * 2 + @flags[to-i]
      end
      bits
    end

    def record( site, url, digest)
      if site.name == 'GOG'
        @gog = url.split('/')[-1] unless @gog
      end

      if site.name == 'Steam'
        @steam = url.split('/')[-1] unless @steam
      end

      (digest['platforms'] || []).each do |aspect|
        record_aspect( aspect)
      end
    end

    def record_aspect( aspect)
      return if @owner.exclude?( aspect)
      @flags[ @owner.aspect_index( aspect)] = 1
    end
  end

  def initialize( dir, cache, templates, local)
    @dir       = dir
    @pagoda    = Pagoda.release( dir, cache)
    @cache     = cache
    @templates = templates
    @local     = local

    seen = {}
    @pagoda.select('aspect') do |record|
      name, index = record[:name], record[:index]
      next unless index
      raise "Duplicate index for aspect #{name}" if seen[index]
      seen[index] = true
    end

    @pagoda.select('aspect') do |record|
      name, index = record[:name], record[:index]
      unless index
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
    @pagoda.get('aspect',:name,aspect)[0][:index]
  end

  def aspect_name_indexes
    @pagoda.select('aspect') do |record|
      yield record[:name], record[:index]
    end
  end

  def exclude?( aspect)
    (@local ? ['Non-mouse'] : ['Non-mouse', 'Played']).include?( aspect)
  end

  def generate( output_dir)
    containers = ['include', 'unused', 'exclude']
    games      = list_games
    is_local   = @local

    aspects_section = template( 'aspects').result( binding)
    filters_section = template( 'filters').result( binding)
    games_section   = template( 'games').result( binding)
    welcome_section = template( 'welcome').result( binding)

    File.open( output_dir + '/index.html', 'w') do |io|
      io.print template('index').result( binding)
    end

    File.open( output_dir + '/index.js', 'w') do |io|
      io.print template('code').result( binding)
    end

    File.open( output_dir + '/data.js', 'w') do |io|
      separ = ''
      io.puts "var games = ["
      games.each do |game|
        io.print "#{separ}['#{game.name.split("'").join("\\'")}'"
        io.print ",#{game.id}"
        io.print ",#{game.year ? game.year : 0}"
        io.print ",#{game.flags(0,31)}"
        io.print ",#{game.flags(32,63)}"
        io.print ",'#{game.steam}'"
        io.puts  ",'#{game.gog}']"
        separ = ','
      end
      io.puts "];"
    end

    # File.open( output_dir + '/filters.html', 'w') do |io|
    #   aspects    = @aspects
    #   containers = ['include', 'unused', 'exclude']
    #   io.print @filters_template.result( binding)
    # end
  end

  def get_game_info( game, playable, seen)
    return if seen[ game.id]

    if (game.year.to_i + 1) >= Time.now.year
      playable.record_aspect( 'Recent')
    end

    unless game.aspects['Non-mouse']
      playable.record_aspect( 'Mouse')
    end

    game.aspects.each_pair do |aspect, flag|
      if @aspects[aspect]
        playable.record_aspect( aspect) if flag
      else
        raise "Unknown aspect #{aspect} for #{game.name}"
      end
    end

    game.links do |link|
      next unless link.valid?
      if link.type == 'Store'
        digest = @pagoda.cached_digest( link.timestamp)
        playable.record( site, link.url, digest)
      end
    end

    seen[game.id] = true
    if game.group_id && (parent = @pagoda.game( game.group_id))
      get_game_info( parent, playable, seen)
    end
  end

  def list_games
    list = []
    @pagoda.game( 0)   # Force index to be created
    @pagoda.games do |game|
      next if game.is_group == 'Y'
      playable = Playable.new( self, game.id, game.name, game.year)
      seen = {}
      get_game_info( game, playable, seen)
      list << playable
    end

    list.sort_by! {|g| g.name}
  end

  def template( name)
    ERB.new( IO.read( @templates + '/' + name + '.erb'))
  end

  def validate( path)
    info = YAML.load( IO.read( @dir + '/' + path))
    info['tags'].each_value do |value|
      if value.is_a?( Array)
        value[1..-1].each do |aspect|
          unless @aspects[aspect]
            raise "Unknown aspect #{aspect} in #{path}"
          end
        end
      end
    end
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0], ARGV[1], ARGV[2], ARGV[4] == 'local')
wfp.validate( 'gog.yaml')
wfp.validate( 'steam.yaml')
wfp.generate( ARGV[3])
