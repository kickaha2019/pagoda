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

    def record
      @record
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
    def initialize( owner, rec)
      super

      owner.add_name( name, id)

      aliases.each do |arec|
        owner.add_name( arec.name, id)
      end
    end

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
      flagged = aspects
      known = []
      @owner.aspect_name_and_types {|name, _| known << name}
      return '?' unless flagged['Adventure']
      ['HOG','Physics','RPG','Stealth','Visual novel','VR'].each do |unwanted|
        raise "Unknown aspect #{unwanted}" unless known.include?( unwanted)
        return '?' if flagged[unwanted]
      end
      'A'
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

      @owner.aspect_name_and_types do |aspect, _|
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

    def update_details( params)
      @owner.start_transaction
      @owner.delete( 'game',    :id, id)
      rec = {}
      @record.each_pair {|k,v| rec[k] = v}
      [:year, :developer, :publisher].each do |field|
        rec[field] = params[field] ? params[field].to_s.strip : rec[field]
      end
      @record = @owner.insert( 'game', rec)
      @owner.end_transaction
      self
    end

    def update_from_link(link)
      details = {}
      site    = @owner.get_site_handler( link.site)
      page    = ''

      begin
        path = @owner.cache_path( link.timestamp)
        page = File.exist?( path) ? IO.read( path) : ''
        site.get_game_details( link.url, page, details)
      rescue Exception => bang
        link.complain bang.message
      end

      [:year, :developer, :publisher].each do |field|
        details.delete(field) unless send(field).nil?
      end

      unless details.empty?
        update_details( details)
      end

      cache_aspects = aspects
      # cache_types = {}
      # cache_aspects.each do |aspect, flag|
      #   type = @owner.get_aspect_type(aspect)
      #   if type && flag
      #     cache_types[aspect] = true
      #   end
      # end

      site.get_aspects(@owner,page) do |aspect|
        if @owner.aspect?(aspect)
            unless cache_aspects.has_key?(aspect)
              # type = @owner.get_aspect_type(aspect)
              # if type && cache_types[type]
              #   link.complain "Multiple type aspect: #{aspect}"
              # else
                @owner.start_transaction
                @owner.insert( 'aspect', {:id => id, :aspect => aspect, :flag => 'Y'})
                @owner.end_transaction
              #              end
            end
        else
          link.complain "Unknown aspect: #{aspect}"
        end
      end
    end

    # def web
    #   'N'
    # end
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

    def complain(msg)
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:comment]    = msg
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end

    def delete
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.delete( 'link', :url, @record[:url])
      @owner.end_transaction
    end

    def generate?
      return false if type == 'Database'
      valid? && collation && (! static?)
    end

    def id
      timestamp
    end

    def label
      orig_title
    end

    def link_date
      begin
        sh = @owner.get_site_handler(site)
        sh.get_link_year( IO.read( @owner.cache_path( timestamp)))
      rescue StandardError => e
        puts e.to_s
      end
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

    def set_checked
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:changed] = 'N'
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end

    def static?
      return false unless @record[:static]
      @record[:static] == 'Y'
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
      sh = @owner.get_site_handler( site)
      @owner.suggest( sh.reduce_title( sh.link_title( title, orig_title))) {|game, freq| yield game, freq}
    end

    def suggest_analysis
      sh = @owner.get_site_handler( site)
      @owner.suggest_analysis( sh.link_title( title, orig_title)) {|combo, hits| yield combo, hits}
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

  def initialize( dir, cache=nil)
    @dir       = dir
    @database  = Database.new( dir)
    log 'Loaded database'
    @names     = Names.new
    @possibles = nil
    @cache     = cache

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
    @database.declare_integer( 'visited',        :timestamp)

    # Populate names repository
    @database.select( 'game') do |game_rec|
      g = PagodaGame.new( self, game_rec)
    end
    log 'Populate names repository'

    @aspect_info_timestamp = 0
    @cached_yaml = {}
    load_site_handlers
    log 'Pagoda opened'
  end

  def aspect?(name)
    aspect_info[name]
  end

  def log( msg)
    puts "#{Time.now.strftime('%H:%S.%L')} - #{msg}"
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

  def aspect_name_and_types
    aspect_info.each_pair do |name, info|
      yield name,info['type'] if info['derive'].nil?
    end
  end

  def cache_path( timestamp)
    slice = (timestamp / (24 * 60 * 60)) % 10
    @cache + "/verified/#{slice}/#{timestamp}.html"
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
    g
  end

  def delete_link( url)
    @database.start_transaction
    @database.delete( 'link', :url, url)
    @database.delete( 'bind', :url, url)
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

  def games_in_group( gid)
    games do |g|
      if g.group_id == gid
        yield g if block_given?
        true
      else
        false
      end
    end
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
    @names.string_combos( name) {|combo, weight| yield combo}
  end

  def suggest( name)
    @names.suggest( name, 20) do |game_id, freq|
      if g = game(game_id)
        yield g, freq
      else
        puts "*** Lost #{game_id} for #{name} suggest"
      end
    end
  end

  def suggest_analysis( name)
    @names.suggest_analysis( name) {|combo, hits, weight| yield combo, hits}
  end

  # Wrapper methods for calls to database and names logic

  def add_link( site, type, title, url, static='N')
    url = get_site_handler( site).coerce_url( url)
    return false if link(url) != nil

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
    true
  end

  def add_name( name, id)
    @names.add(name, id)
  end

  def get_aspect_type(aspect)
    if info = aspect_info[aspect]
      info['type']
    else
      nil
    end
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
      puts"... Deleting lost aspect #{aspect}"
      @database.delete( 'aspect', :aspect, aspect)
    end
    end_transaction
    puts "*** Deleted #{aspects_lost.size} lost aspect records" if aspects_lost.size > 0

    visited_lost, now3y = [], Time.new( Time.now.year - 3).to_i
    @database.select( 'visited') do |rec|
      unless rec[:timestamp] >= now3y
        visited_lost << rec[:key]
      end
    end
    start_transaction
    visited_lost.each do |key|
      @database.delete( 'visited', :key, key)
    end
    end_transaction
    puts "*** Deleted #{visited_lost.size} old visited records" if visited_lost.size > 0
  end

  def clean_cache
    deleted = 0
    Dir.entries( @cache + '/verified').each do |section|
      next if /^[._]/ =~ section
      Dir.entries( @cache + '/verified/' + section).each do |f|
        /^(\d+)\.html$/.match( f) do |m|
          unless @database.has?( 'link', :timestamp, m[1].to_i) ||
                 @database.has?( 'old_links', :timestamp, m[1].to_i)
            path = @cache + '/verified/' + section + '/' + f
            File.delete path
            deleted += 1
          end
        end
      end
    end
    puts "*** Deleted #{deleted} cached files" if deleted > 0
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

  def update_link( url, site, type, title, new_url, static='N')
    @database.start_transaction
    @database.delete( 'link', :url, url)
    insert( 'link',
            {:site       => site,
             :type       => type,
             :title      => title,
             :orig_title => title,
             :url        => new_url,
             :static     => static,
             :timestamp  => 1})
    @database.end_transaction
  end

  def visited_key( key)
    start_transaction
    @database.delete( 'visited', :key, key)
    @database.insert( 'visited', {:key => key, :timestamp => Time.now.to_i})
    end_transaction
  end
end