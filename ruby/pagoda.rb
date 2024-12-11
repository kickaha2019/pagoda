require 'yaml'

require_relative 'file_database'
require_relative 'names'
require_relative 'pagoda_record'
require_relative 'pagoda_alias'
require_relative 'pagoda_collation'
require_relative 'pagoda_game'
require_relative 'pagoda_link'

class Pagoda
  attr_reader :settings

  def initialize( database, metadata, cache=nil)
    @dir         = metadata
    @database    = database
    @settings    = YAML.load( IO.read( @dir + '/settings.yaml'))
    log 'Loaded database'
    @names       = Names.new
    @possibles   = nil
    @cache       = cache

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
      PagodaGame.new( self, game_rec)
    end
    log 'Populate names repository'

    @aspect_info_timestamp = 0
    load_site_handlers
    @pagoda_links = load_links
    log 'Pagoda opened'
  end

  def self.release(dir, cache=nil)
    Pagoda.new(FileDatabase.new( dir), dir, cache)
  end

  def self.testing(metadata, cache)
    database = Database.new
    database.add_table(Table.new('alias',[:id,:name,:hide,:sort_name],[]))
    database.add_table(Table.new('aspect',[:id,:aspect,:flag],[]))
    database.add_table(Table.new('aspect_suggest',[:game,:aspect,:text,:cache,:visit,:timestamp,:site],[]))
    database.add_table(Table.new('bind',[:url,:id],[]))
    database.add_table(Table.new('company_alias',[:name,:alias],[]))
    database.add_table(Table.new('company',[:name],[]))
    database.add_table(Table.new('game',[:id,:name,:is_group,:group_id,:game_type,:year,:developer,:publisher],[]))
    database.add_table(Table.new('link',[:site,:type,:title,:url,:timestamp,:valid,:comment,:orig_title,:changed,:year,:static],[]))
    database.add_table(Table.new('old_links',[:site,:type,:title,:url,:timestamp,:valid,:comment,:orig_title,:changed,:year,:static],[]))
    database.add_table(Table.new('visited',[:key,:timestamp],[]))
    Pagoda.new(database, metadata, cache)
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

  def cache_path( timestamp, extension)
    slice = (timestamp / (24 * 60 * 60)) % 10
    @cache + "/verified/#{slice}/#{timestamp}.#{extension}"
  end

  def cached_digest( timestamp)
    slice = (timestamp / (24 * 60 * 60)) % 10
    path = @cache + "/verified/#{slice}/#{timestamp}.yaml"
    if File.exist?( path)
      YAML.load(IO.read(path))
    else
      {}
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
    g
  end

  def delete_link( url)
    @database.start_transaction
    @database.delete( 'bind', :url, url)
    @database.delete( 'link', :url, url)
    @database.end_transaction
    @pagoda_links.delete(url)
  end

  def game( id)
    recs = get( 'game', :id, id.to_i)
    return nil if recs.size <= 0
    PagodaGame.new( self, recs[0])
  end

  def digest_aspects(link, digest)
    if digest['aspects']
      digest['aspects'].uniq.each do |aspect|
        if ['accept','reject'].include?(aspect)
          yield aspect
        elsif aspect?(aspect)
          yield aspect
        else
          link.complain "Unknown aspect: #{aspect}"
        end
      end
    elsif digest['tags']
      aspects = []

      digest['tags'].each do |tag|
        found = false

        get('tag_aspects',:tag,tag).each do |rec|
          found = true
          unless rec[:aspect].nil?
            aspects << rec[:aspect]
          end
        end

        unless found
          start_transaction
          insert('tag_aspects', {tag:tag, aspect:'Unknown'})
          end_transaction
          aspects << 'Unknown'
        end
      end

      aspects.uniq.each do |aspect|
        if ['accept','reject'].include?(aspect)
          yield aspect
        elsif aspect?(aspect)
          yield aspect
        else
          link.complain "Unhandled tag for #{link.site}"
        end
      end
    end
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
    @pagoda_links[url]
  end

  def links
    selected = []
    @pagoda_links.each_value do |link|
      selected << link if (! block_given?) || (yield link)
    end
    selected
  end

  def load_links
    {}.tap do |links|
      @database.select( 'link') do |rec|
        links[rec[:url]] = PagodaLink.new( self, rec)
        binds = get('bind',:url,rec[:url])
        if binds.size > 0
          links[rec[:url]]._bind(binds[0][:id])
        end
      end
    end
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
  def add_link( site, type, title, url)
    url = get_site_handler( site).coerce_url( url)
    return false unless link(url).nil?

    rec = {:site       => site,
           :type       => type,
           :title      => title,
           :orig_title => title,
           :url        => url,
           :timestamp  => 1}
    insert_link rec
    true
  end

  def insert_link( rec)
    start_transaction
    insert( 'link', rec)
    end_transaction
    refresh_link rec[:url]
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
    puts "*** Deleted #{count} bind records no link" if count > 0
    count = @database.clean_missing_positive( 'bind', :id, 'game', :id).size
    puts "*** Deleted #{count} bind records no game" if count > 0

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

  def refresh_link(url)
    if rec = @database.get('link', :url, url)[0]
      @pagoda_links[url] = PagodaLink.new(self,rec)
      binds = get('bind',:url,url)
      if binds.size > 0
        @pagoda_links[url]._bind(binds[0][:id])
      end
    else
      @pagoda_links.delete(url)
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

  def update_link(link, rec, digest, debug=false)

    # Save old link to old_links table
    start_transaction
    delete('old_links',:url, link.url)
    insert('old_links',link.record)
    end_transaction

    # Save the digest
    sleep 1
    rec[:timestamp] = Time.now.to_i
    new_path = cache_path( rec[:timestamp], 'yaml')
    File.open( new_path, 'w') {|io| io.print digest.to_yaml}
    p ['update_link5', new_path] if debug

    # Unbind unreleased links
    if rec[:unreleased]
      link.unbind
    elsif ignore_link(link, digest)
      link.bind( -1) unless link.bound?
    end

    link.verified( rec)
    refresh_link link.url
  end

  def ignore_link(link, digest)
    has_aspects = digest['aspects'] || digest['tags']

    digest_aspects(link, digest) do |aspect|
      has_aspects = true
      return true if aspect == 'reject'
    end
    digest_aspects(link, digest) do |aspect|
      return false if aspect == 'accept'
    end
    has_aspects
  end

  def visited_key( key)
    start_transaction
    @database.delete( 'visited', :key, key)
    @database.insert( 'visited', {:key => key, :timestamp => Time.now.to_i})
    end_transaction
  end
end