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

    def console
      'N'
    end

    def delete
      @owner.start_transaction
      @owner.delete( 'game',    :id, id)
      @owner.delete( 'alias',   :id, id)
      @owner.delete( 'bind',    :id, id)
      @owner.remove_name_id( id)
      @owner.end_transaction
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

    def mac
      'N'
    end

    def pc
      'N'
    end

    def phone
      'N'
    end

    def sort_name
      @owner.sort_name( name)
    end

    def tablet
      'N'
    end

    def update( params)
      @owner.start_transaction
      @owner.delete( 'game',    :id, id)
      @owner.delete( 'alias',   :id, id)
      @owner.remove_name_id( id)

      rec = {}
      [:id, :name, :year, :is_group, :developer, :publisher, :game_type].each do |field|
        rec[field] = params[field] ? params[field].strip : nil
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
      return nil unless @record && (@record[:valid] == 'Y')
      binds = @owner.get( 'bind', :url, @record[:url])
      if binds.size > 0
        return nil if binds[0][:id] < 0
        @owner.game( binds[0][:id])
      else
        game_id = @owner.lookup( @record[:site], @record[:type], @record[:title])
        return nil if game_id.nil?
        @owner.game( game_id)
      end
    end

    def delete
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.delete( 'link', :url, @record[:url])
      @owner.end_transaction
    end

    def generate?
      (@record[:valid] == 'Y') && collation
    end

    def id
      timestamp
    end

    def label
      (@record[:title] && (@record[:title].strip != '')) ? @record[:title] : '???'
    end

    def name
      label
    end

    def redirected?
      @record[:redirect] == 'Y'
    end

    def timestamp
      @record[:timestamp] ? @record[:timestamp].to_i : 0
    end

    def unbind
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.end_transaction
    end

    def valid?
      @record[:valid] == 'Y'
    end

    def verified( title, timestamp, valid, redirected)
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @record[:title]     = title
      @record[:timestamp] = timestamp
      @record[:valid]     = valid
      @record[:redirect]  = redirected
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end
  end

  def initialize( dir)
    @database  = Database.new( dir)
    @names     = Names.new
    @possibles = nil

    @database.declare_integer( 'alias', :id)
    @database.declare_integer( 'bind',  :id)
    @database.declare_integer( 'game',  :id)
    @database.declare_integer( 'game',  :group_id)
    @database.declare_integer( 'game',  :year)
    @database.declare_integer( 'link',  :timestamp)

    # Populate names repository
    @database.select( 'game') do |game_rec|
      g = PagodaGame.new( self, game_rec)
      if g.game_type == 'A'
        @names.add( g.name, g.id)

        g.aliases.each do |arec|
          @names.add( arec.name, g.id)
        end
      end
    end

    @reduction_file      = dir + '/collation.yaml'
    @reduction_timestamp = 0
    @reductions          = {}
    refresh_reduction_cache
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

  def link( url)
    PagodaLink.new( self, get( 'link', :url, url)[0])
  end

  def links
    selected = []
    @database.select( 'link') do |rec|
      s = PagodaLink.new( self, rec)
      selected << s if (! block_given?) || (yield s)
    end
    selected
  end

  # def reverify( url)
  #   rec = @database.get( 'link', :url, url)[0]
  #   rec[:valid] = 'Y'
  #   @database.start_transaction
  #   @database.delete( 'link', :url, url)
  #   @database.insert( 'link', rec)
  #   @database.end_transaction
  # end

  def string_combos( name)
    words = @names.reduce( name).split( ' ')
    words.each {|word| yield word, 125}

    (0..(words.size-2)).each do |i|
      yield words[i..(i+1)].join(' '), 25
    end

    (0..(words.size-3)).each do |i|
      yield words[i..(i+2)].join(' '), 5
    end

    (0..(words.size-4)).each do |i|
      yield words[i..(i+3)].join(' '), 1
    end
  end

  # Wrapper methods for calls to database and names logic

  def add_name( name, id)
    @names.add(name, id)
  end

  def count( table_name)
    @database.count( table_name)
  end

  def end_transaction
    @database.end_transaction
  end

  def delete( table_name, column_name, column_value)
    @database.delete( table_name, column_name, column_value)
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

  def lookup( site, type, name)
    return nil if name.nil? || (name.strip == '')

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

    @names.lookup(name)
  end

  def matches( name)
    @names.matches(name)
  end

  def next_value( table_name, column_name)
    @database.next_value( table_name, column_name)
  end

  def rebuild
    @database.rebuild
  end

  def reduce_name( name)
    @names.reduce(name)
  end

  def refresh_reduction_cache
    t = File.mtime( @reduction_file)
    if @reduction_timestamp != t
      @reductions          = YAML.load( IO.read( @reduction_file))
      @reduction_timestamp = t
    end
  end

  def remove_name_id( id)
    @names.remove(id)
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
end