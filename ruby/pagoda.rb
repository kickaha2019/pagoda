require 'yaml'

require_relative 'database'
require_relative 'names'

class Pagoda
  class PagodaRecord
    def initialize( owner, rec)
      @owner  = owner
      @record = rec
    end

    def generate?
      true
    end

    def method_missing( m, *args, &block)
      if (args.size > 0) || block
        super
      else
        @record[m]
      end
    end
  end

  class PagodaAlias < PagodaRecord
    def sort_name
      @owner.sort_name( name)
    end
  end

  class PagodaCollation < PagodaRecord
    def rank
      0
    end
  end

  class PagodaExpect < PagodaRecord
  end

  class PagodaGame < PagodaRecord
    def aliases
      @owner.get( 'alias', :id, id).collect {|rec| PagodaAlias.new( @owner, rec)}
    end

    def aspects
      map = {}
      @owner.get( 'aspect', :id, id).each do |rec|
        f, a = rec[:flag], rec[:aspect]
        if f == 'Y'
          map[a] = true
        elsif f == 'N'
          map[a] = false
        end
      end
      map
    end

    def console
      'N'
    end

    def delete
      @owner.delete_name( name, id)
      aliases.each do |a|
        @owner.delete_name( a.name, id)
      end
      links do |l|
        @owner.delete_name( l.title, id)
      end
      @owner.start_transaction
      @owner.delete( 'game',           :id,   id)
      @owner.delete( 'alias',          :id,   id)
      @owner.delete( 'bind',           :id,   id)
      @owner.delete( 'aspect',         :id,   id)
      @owner.delete( 'aspect_suggest', :game, id)
      @owner.end_transaction
    end

    def game_type
      'A'
    end

    def generate?
      flagged = aspects
      known = []
      @owner.aspect_names {|name| known << name}
      return false unless flagged['Adventure']
      ['Action','HOG','Physics','Roguelike','RPG','Stealth','Visual novel','VR'].each do |unwanted|
        raise "Unknown aspect #{unwanted}" unless known.include?( unwanted)
        return false if flagged[unwanted]
      end
      true
    end

    def group_name
      if @record[:group_id]
        if group = @owner.get( 'game', :id, @record[:group_id])[0]
          group[:name]
        else
          nil
        end
      else
        nil
      end
    end

    def links
      @owner.get( 'bind', :id, id).each do |rec|
        if link = @owner.link( rec[:url])
          yield link
        end
      end
    end

    def mac
      'N'
    end

    def pc
      'N'
    end

    def official_site
      @owner.get( 'bind', :id, id).each do |rec|
        if @owner.has?( 'link', :url, rec[:url])
          link = @owner.link( rec[:url])
          if link.site == 'Website' && link.type == 'Official'
            return rec[:url]
          end
        end
      end
      ''
    end

    def phone
      'N'
    end

    def sort_name
      @owner.sort_name( name)
    end

    def suggest_analysis
      @owner.suggest_analysis( name) {|combo, hits| yield combo, hits}
      aliases.each do |a|
        @owner.suggest_analysis( a.name) {|combo, hits| yield combo, hits}
      end
    end

    def tablet
      'N'
    end

    def update( params)
      @owner.delete_name( name, id)
      aliases.each do |a|
        @owner.delete_name( a.name, id)
      end

      @owner.start_transaction
      @owner.delete( 'game',    :id, id)
      @owner.delete( 'alias',   :id, id)
      @owner.delete( 'aspect',  :id, id)

      rec = {}
      [:id, :name, :year, :is_group, :developer, :publisher].each do |field|
        rec[field] = params[field] ? params[field].to_s.strip : nil
      end

      if params[:group_name]
        group_recs = @owner.get( 'game', :name, params[:group_name].strip)
        rec[:group_id] = group_recs[0][:id] if group_recs && group_recs[0]
      end

      @record = @owner.insert( 'game', rec)
      @owner.add_name( rec[:name], id)
      names_seen = {rec[:name].downcase => true}

      (0..20).each do |index|
        name = params["alias#{index}".to_sym]
        next if name.nil? || (name.strip == '')
        next if names_seen[name.downcase]
        rec = {id:id, name:name, hide:params["hide#{index}".to_sym]}
        @owner.insert( 'alias', rec)
        @owner.add_name( rec[:name], id)
        names_seen[name.downcase] = true
      end

      @owner.aspect_names do |aspect|
        f = params["a_#{aspect}".to_sym]
        if ['Y','N'].include?( f)
          $pagoda.insert( 'aspect', {:id => id, :aspect => aspect, :flag => f})
        end
      end

      os = official_site
      if params[:website] && (os != params[:website])
        @owner.delete( 'bind', :url, os)
        @owner.delete( 'link', :url, os)
        if params[:website] != ''
          @owner.insert( 'link', {:url => params[:website], :site => 'Website', :type => 'Official', :title => name})
          @owner.insert( 'bind', {:url => params[:website], :id => id})
        end
      end

      @owner.end_transaction
      self
    end

    def web
      'N'
    end
  end

  class PagodaLink < PagodaRecord
    def bind( id)
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.insert( 'bind', {
          url:@record[:url],
          id:id
      })
      @owner.end_transaction
    end

    def bound?
      @owner.has?( 'bind', :url, @record[:url])
    end

    def collation
      return nil unless @record
      binds = @owner.get( 'bind', :url, @record[:url])
      if binds.size > 0
        return nil if binds[0][:id] < 0
        @owner.game( binds[0][:id])
      else
        nil
      end
    end

    # def comment?
    #   return false unless @record[:comment]
    #   raise 'Unexpected comment value' if @record[:comment].strip == ''
    #   @record[:comment].strip != ''
    # end

    def delete
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.delete( 'link', :url, @record[:url])
      @owner.end_transaction
    end

    def generate?
        valid? && collation && (! static)
    end

    def id
      timestamp
    end

    def label
      orig_title
    end

    def name
      title
    end

    def orig_title
      (@record[:orig_title] && (@record[:orig_title].strip != '')) ? @record[:orig_title] : '???'
    end

    def patch_orig_title( title)
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:orig_title] = title
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end

    def reduced_name
      @owner.reduce_name_for_site(@record[:site], @record[:type], @record[:orig_title])
    end

    def set_checked
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:changed] = 'N'
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end

    def status
      if ! valid?
        if bound? && collation.nil?
          'Ignored'
        else
          'Invalid'
        end
      elsif bound?
        collation ? 'Bound' : 'Ignored'
      else
        'Free'
      end
    end

    def suggest
      @owner.suggest( title) {|game| yield game}
    end

    def suggest_analysis
      @owner.suggest_analysis( title) {|combo, hits| yield combo, hits}
    end

    def timestamp
      @record[:timestamp] ? @record[:timestamp].to_i : 0
    end

    def title
      (@record[:title] && (@record[:title].strip != '')) ? @record[:title] : '???'
    end

    def unbind
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.end_transaction
    end

    def valid?
      @record[:valid] == 'Y'
    end

    def verified( rec)
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:url] = rec[:url] if rec[:url]

      unless @owner.has?( 'link', :url, @record[:url])
        @record[:title]      = rec[:title]
        ot = @record[:orig_title]
        ot = rec[:title] if ot.nil? || (ot.strip == '')
        @record[:orig_title] = rec[:orig_title] ? rec[:orig_title] : ot
        @record[:timestamp]  = rec[:timestamp]
        @record[:valid]      = rec[:valid] ? 'Y' : 'N'
        @record[:comment]    = rec[:comment]
        @record[:changed]    = rec[:changed] ? 'Y' : @record[:changed]
        @record[:year]       = rec[:year] ? rec[:year] : nil
        @owner.insert( 'link', @record)
      end
      @owner.end_transaction
    end
  end

  def initialize( dir)
    @dir       = dir
    @database  = Database.new( dir)
    @names     = Names.new
    @possibles = nil

    @database.declare_integer( 'alias',          :id)
    @database.declare_integer( 'aspect',         :id)
    @database.declare_integer( 'aspect_suggest', :game)
    @database.declare_integer( 'aspect_suggest', :cache)
    @database.declare_integer( 'aspect_suggest', :timestamp)
    @database.declare_integer( 'bind',           :id)
    @database.declare_integer( 'game',           :id)
    @database.declare_integer( 'game',           :group_id)
    @database.declare_integer( 'game',           :year)
    @database.declare_integer( 'link',           :timestamp)
    @database.declare_integer( 'link',           :year)

    # Populate names repository
    @database.select( 'game') do |game_rec|
      g = PagodaGame.new( self, game_rec)
      @names.add( g.name, g.id)

      g.aliases.each do |arec|
        @names.add( arec.name, g.id)
      end

      g.links do |l|
        @names.add( l.title, g.id)
      end
    end

    @reduction_file        = dir + '/collation.yaml'
    @reduction_timestamp   = 0
    @reductions            = {}
    @aspect_info_timestamp = 0
    refresh_reduction_cache

    @cached_yaml = {}
    load_site_handlers
  end

  def aliases
    list = []
    games.each do |g|
      g.aliases.each do |a|
        list << a
      end
    end
    list
  end

  def aspect_info
    unless @aspect_info_timestamp == File.mtime( @dir + '/aspects.yaml')
      @aspect_info_timestamp == File.mtime( @dir + '/aspects.yaml')
      @aspect_info = YAML.load( IO.read( @dir + '/aspects.yaml'))
    end
    @aspect_info
  end

  def aspect_names
    aspect_info.each_pair do |name, info|
      yield name if info['derive'].nil?
    end
  end

  def check_unique_name( name, id)
    return true if name.nil? or name == ''
    @names.check_unique_name( name, id.to_i)
  end

  def check_unique_names( params)
    id = params[:id]
    return false unless check_unique_name( params[:name], id)
    (0..20).each do |index|
      return false unless check_unique_name( params["alias#{index}"], id)
    end
    true
  end

  def clear_collation_ids( id)
    to_clear = links.select {|s| s.cached_collation == id}
    to_clear.each do |s|
      s.clear_collation_id
    end
  end

  def collations
    links.select {|s| s.generate?}.collect do |s|
      PagodaCollation.new( self, {id:s.collation.id, link:s.id})
    end
  end

  def contains_string( text, search)
    text   = text.to_s
    search = search.downcase
    return true if text.downcase.index( search)
    @names.reduce( text).index( search)
  end

  def correlate_site( url)
    site = type = link = nil
    @site_handlers.each_value do |handler|
      site, type, link = handler.correlate_url( url)
      #p [handler.name, site, type, link]
      break if site
    end
    return site, type, link
  end

  def create_game( params)
    raise 'Names not unique' unless check_unique_names( params)
    g = PagodaGame.new( self, {id:params[:id]})
    g.update( params)
  end

  def delete_link( url)
    @database.start_transaction
    @database.delete( 'link', :url, url)
    @database.end_transaction
  end

  def game( id)
    recs = get( 'game', :id, id.to_i)
    return nil if recs.size <= 0
    PagodaGame.new( self, recs[0])
  end

  def games
    selected = []
    @database.select( 'game') do |rec|
      g = PagodaGame.new( self, rec)
      selected << g if (! block_given?) || (yield g)
    end
    selected
  end

  def generate_links
    links {|link| link.generate?}
  end

  def get_site_handler( site)
    if @site_handlers[site]
      @site_handlers[site]
    else
      @site_handlers['Website']
    end
  end

  def get_yaml( f)
    YAML.load( IO.read( @dir + '/' + f))
  end

  def link( url)
    if rec = get( 'link', :url, url)[0]
      PagodaLink.new( self, rec)
    else
      nil
    end
  end

  def links
    selected = []
    @database.select( 'link') do |rec|
      s = PagodaLink.new( self, rec)
      selected << s if (! block_given?) || (yield s)
    end
    selected
  end

  def load_site_handlers
    @site_handlers = {}
    dir = File.dirname( self.method( :load_site_handlers).source_location[0])
    Dir.new( dir + '/sites').entries.each do |f|
      if m = /^(.*).rb$/.match( f)
        require( dir + '/sites/' + f)
        handler = Kernel.const_get( m[1].split('_').collect {|w| w.capitalize}.join( '')).new
        @site_handlers[ handler.name] = handler
      end
    end
  end

  def put_yaml( data, f)
    File.open( @dir + '/' + f, 'w') {|io| io.print data.to_yaml}
  end

  # def reverify( url)
  #   rec = @database.get( 'link', :url, url)[0]
  #   rec[:valid] = 'Y'
  #   @database.start_transaction
  #   @database.delete( 'link', :url, url)
  #   @database.insert( 'link', rec)
  #   @database.end_transaction
  # end

  def scan_stats_records
    path = @dir + "/scan_stats.yaml"
    if File.exist?( path)
      info = YAML.load( IO.read( path))
      info.keys.sort.each do |site|
        info[site].keys.sort.each do |section|
          ss = info[site][section]
          yield site, section, ss['max_count'], Time.at( ss['max_date'])
        end
      end
    end
  end

  def string_combos( name)
    @names.string_combos( name) {|combo| yield combo}
  end

  def suggest( name)
    @names.suggest( name, 20) {|game_id| yield game(game_id)}
  end

  def suggest_analysis( name)
    @names.suggest_analysis( name) {|combo, hits| yield combo, hits}
  end

  # Wrapper methods for calls to database and names logic

  def add_link( site, type, title, url, static='N')
    url = get_site_handler( site).coerce_url( url)
    return if link(url) != nil

    start_transaction
    insert( 'link',
                    {:site       => site,
                             :type       => type,
                             :title      => title,
                             :orig_title => title,
                             :url        => url,
                             :static     => static,
                             :timestamp  => 1})
    end_transaction
  end

  def add_name( name, id)
    @names.add(name, id)
  end

  def clean
    count = @database.clean_missing( 'alias', :id, 'game', :id).size
    puts "*** Deleted #{count} alias records" if count > 0
    count = @database.clean_missing( 'aspect', :id, 'game', :id).size
    puts "*** Deleted #{count} aspect records" if count > 0
    count = @database.clean_missing( 'aspect_suggest', :game, 'game', :id).size
    puts "*** Deleted #{count} aspect suggest records" if count > 0
    count = @database.clean_missing( 'bind', :url, 'link', :url).size
    puts "*** Deleted #{count} bind records" if count > 0

    aspects_lost = []
    @database.select( 'aspect') do |rec|
      unless aspect_info[rec[:aspect]]
        aspects_lost << rec[:aspect]
      end
    end
    start_transaction
    aspects_lost.uniq.each do |aspect|
      @database.delete( 'aspect', :aspect, aspect)
    end
    end_transaction
    puts "*** Deleted #{aspects_lost.size} aspect records" if aspects_lost.size > 0
  end

  def count( table_name)
    @database.count( table_name)
  end

  def delete( table_name, column_name, column_value)
    @database.delete( table_name, column_name, column_value)
  end

  def delete_name( name, id)
    @names.remove( name, id)
  end

  def end_transaction
    @database.end_transaction
  end

  def get( table_name, column_name, column_value)
    @database.get( table_name, column_name, column_value)
  end

  def has?( table_name, column_name, column_value)
    @database.has?( table_name, column_name, column_value)
  end

  def insert( table_name, table_rec)
    @database.insert( table_name, table_rec)
  end

  def keys( id)
    @names.keys(id)
  end

  def next_value( table_name, column_name)
    @database.next_value( table_name, column_name)
  end

  def rarity( name)
    @names.rarity( name)
  end

  def rebuild
    @database.rebuild
  end

  def reduce_name( name)
    @names.reduce(name)
  end

  def reduce_name_for_site(site, type, name)
    if reductions = @reductions[site]
      if reductions = reductions[type]
        reductions.each do |reduction|
          re = Regexp.new( reduction)
          if m = re.match( name)
            name = m[1]
          end
        end
      end
    end

    @names.reduce(name)
  end

  def refresh_reduction_cache
    t = File.mtime( @reduction_file)
    if @reduction_timestamp != t
      @reductions          = YAML.load( IO.read( @reduction_file))
      @reduction_timestamp = t
    end
  end

  def select( table_name)
    @database.select( table_name) do |rec|
      yield rec
    end
  end

  def sort_name( name)
    name = @names.simplify(name)
    if m = /^(a|an|the) (.*)$/.match( name)
      name = m[2]
    end

    name = name.strip.upcase
    if /^\d/ =~ name
      '#' + name
    else
      name
    end
  end

  def start_transaction
    @database.start_transaction
  end

  def terminate
    @site_handlers.each_value {|handler| handler.terminate( self)}
  end
end