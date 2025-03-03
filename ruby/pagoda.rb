require 'yaml'

#require_relative 'file_database'
require_relative 'sqlite_database'
require_relative 'names'
require_relative 'pagoda_record'
require_relative 'pagoda_alias'
require_relative 'pagoda_collation'
require_relative 'pagoda_game'
require_relative 'pagoda_link'

class Pagoda
  attr_reader :settings, :now, :directory

  def initialize( database, metadata)
    @directory   = metadata
    @database    = database
    @settings    = YAML.load( IO.read( @directory + '/settings.yaml'))
    log 'Loaded database'
    @possibles   = nil
    @now         = Time.now

    #@aspect_info_timestamp = Time.utc(1970)
    load_site_handlers
    @pagoda_links = load_links
    log 'Pagoda opened'
  end

  def self.release(dir, log=false)
    Pagoda.new(SqliteDatabase.new( dir + '/pagoda.sqlite'), dir)
  end

  def close_database
    @database.close
  end

  def reopen_database
    @database.reopen
  end

  def aspect?(name)
    @database.has?('aspect', :name, name)
    #aspect_info[name]
  end

  def log( msg)
    puts "#{Time.now.strftime('%H:%M:%S.%L')} - #{msg}"
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

  def aspect_name_and_types
    @database.select('aspect') do |record|
      yield record[:name],record[:type] unless record[:derive]
    end
  end

  def check_unique_name( name, id)
    return true if name.nil? or name == ''
    got = @database.get('game', :name, name)
    if got.empty?
      got = @database.get('alias', :name, name)
    end
    if got.empty?
      true
    else
      got[0][:id] != id
    end
  end

  def check_unique_names( params)
    id = params[:id].to_i
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
        tag = tag.strip
        next if tag.empty?

        if ['accept','reject'].include?(tag)
          aspects << tag
          next
        end

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
        next if aspect.empty?
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

  def get_digest(link_record)
      link_record[:digest] ? JSON.parse(link_record[:digest]) : {}
  end

  def get_site_handler( site)
    if @site_handlers[site]
      @site_handlers[site]
    else
      @site_handlers['Website']
    end
  end

  def get_yaml( f)
    YAML.load( IO.read( @directory + '/' + f))
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
    File.open( @directory + '/' + f, 'w') {|io| io.print data.to_yaml}
  end

  # def string_combos( name)
  #   @names.string_combos( name) {|combo, weight| yield combo}
  # end

  def suggest( name)
    name = name.gsub(/\(\d\d\d\d\)/, ' ')
    @names.suggest( name, 20) do |game_id, freq|
      if g = game(game_id)
        yield g, freq
      else
        puts "*** Lost #{game_id} for #{name} suggest"
      end
    end
  end

  # def suggest_analysis( name)
  #   @names.suggest_analysis( name) {|combo, hits, weight| yield combo, hits}
  # end

  # Wrapper methods for calls to database and names logic
  def add_link( site, type, title, url)
    url = get_site_handler( site).coerce_url( url)
    return false unless link(url).nil?

    rec = {:site       => site,
           :type       => type,
           :title      => title,
           :orig_title => title,
           :url        => url,
           :timestamp  => 1,
           :valid      => false,
           :static     => false,
           :reject     => false}
    insert_link rec
    true
  end

  def add_listener(table, listener)
    @database.add_listener table, listener
  end

  def insert_link( rec)
    start_transaction
    insert( 'link', rec)
    end_transaction
    refresh_link rec[:url]
  end

  def get_aspect_type(aspect)
    @database.get('aspect',:name,aspect)[0][:type]
  end

  def clean
    count = @database.clean_missing( 'alias', :id, 'game', :id).size
    puts "*** Deleted #{count} alias records" if count > 0
    count = @database.clean_missing( 'game_aspect', :id, 'game', :id).size
    puts "*** Deleted #{count} aspect records" if count > 0
    count = @database.clean_missing( 'bind', :url, 'link', :url).size
    puts "*** Deleted #{count} bind records no link" if count > 0
    count = @database.clean_missing_positive( 'bind', :id, 'game', :id).size
    puts "*** Deleted #{count} bind records no game" if count > 0

    aspects_lost = []
    @database.select( 'game_aspect') do |rec|
      unless @database.has?("aspect",:name,rec[:aspect])
        aspects_lost << rec[:aspect]
      end
    end
    start_transaction
    aspects_lost.uniq.each do |aspect|
      puts"... Deleting lost aspect #{aspect}"
      @database.delete( 'game_aspect', :aspect, aspect)
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

  def count( table_name)
    @database.count( table_name)
  end

  def delete( table_name, column_name, column_value)
    @database.delete( table_name, column_name, column_value)
  end

  def end_transaction
    @database.end_transaction
  end

  def get( table_name, column_name, column_value)
    if block_given?
      @database.get( table_name, column_name, column_value) do |record|
        yield record
      end
    else
      @database.get( table_name, column_name, column_value)
    end
  end

  def has?( table_name, column_name, column_value)
    @database.has?( table_name, column_name, column_value)
  end

  def insert( table_name, table_rec)
    @database.insert( table_name, table_rec)
  end

  # def keys( id)
  #   @names.keys(id)
  # end

  def next_value( table_name, column_name)
    @database.next_value( table_name, column_name)
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
      block_given? ? (yield rec) : true
    end
  end

  def sort_name( name)
    name = Names.simplify(name)
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

    # Clean the digest
    ['developers','publishers'].each do |key|
      if digest[key]
        digest[key] = digest[key].collect {|name| name.strip}.select {|name| ! ['','-'].include? name}
      end
    end

    # Unbind rejected links
    rec[:reject] = true if reject_link?(link, digest)

    if rec[:reject]
      link.unbind if link.bound? && link.collation.nil?
    end

    link.verified( rec)
    refresh_link link.url
  end

  def reject_link?(link, digest)
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

  def set_now(t)
    @now = t
  end

  def update( table_name, column_name, value, record)
    @database.update( table_name, column_name, value, record)
  end

  def visited_key( key)
    start_transaction
    @database.delete( 'visited', :key, key)
    @database.insert( 'visited', {:key => key, :timestamp => Time.now.to_i})
    end_transaction
  end
end