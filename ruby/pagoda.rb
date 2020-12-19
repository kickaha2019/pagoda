require_relative 'database'
require_relative 'names'

class Pagoda
  class PagodaAlias
    def initialize( owner, rec)
      @owner  = owner
      @record = rec
    end

    def hide
      @record[:hide]
    end

    def id
      @record[:id]
    end

    def name
      @record[:name]
    end

    def sort_name
      @owner.sort_name( name)
    end
  end

  class PagodaCollation
    def initialize( owner, rec)
      @owner  = owner
      @record = rec
    end

    def id
      @record[:id]
    end

    def link
      @record[:link]
    end

    def rank
      0
    end
  end

  class PagodaGame
    def initialize( owner, rec)
      @owner  = owner
      @record = rec
    end

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

    def developer
      @record[:developer]
    end

    def game_type
      @record[:game_type]
    end

    def group_name
      @record[:group_name]
    end

    def id
      @record[:id]
    end

    def is_group
      @record[:is_group]
    end

    def mac
      'N'
    end

    def name
      @record[:name]
    end

    def pc
      'N'
    end

    def phone
      'N'
    end

    def publisher
      @record[:publisher]
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
      [:id, :name, :year, :is_group, :group_name, :developer, :publisher, :game_type].each do |field|
        rec[field] = params[field] ? params[field].strip : nil
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

    def year
      @record[:year]
    end
  end

  class PagodaScan
    def initialize( owner, rec)
      @owner  = owner
      @record = rec
    end

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
      binds = @owner.get( 'bind', :url, @record[:url])
      binds.size > 0
    end

    def collation
      binds = @owner.get( 'bind', :url, @record[:url])
      if binds.size > 0
        return nil if binds[0][:id] < 0
        @owner.game( binds[0][:id])
      else
        game_id = @owner.lookup( @record[:name])
        return nil if game_id.nil?
        @owner.game( game_id)
      end
    end

    def id
      @record[:id]
    end

    def label
      @record[:label]
    end

    def name
      @record[:name]
    end

    def site
      @record[:site]
    end

    def type
      @record[:type]
    end

    def unbind
      @owner.start_transaction
      @owner.delete( 'bind', :url, @record[:url])
      @owner.end_transaction
    end

    def url
      @record[:url]
    end
  end

  def initialize( dir)
    @database = Database.new( ARGV[0])
    @names    = Names.new
    #$database.join( 'scan', :bind, :url, 'bind', :url)
    #$database.join( 'game', :aliases, :id, 'alias', :id)

    @database.select( 'game') do |game_rec|
      g = PagodaGame.new( self, game_rec)
      @names.add( g.name, g.id)
      g.aliases.each do |arec|
        @names.add( arec.name, g.id)
      end
    end
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
    scans.select {|s| s.collation}.collect do |s|
      PagodaCollation.new( self, {id:s.collation.id, link:s.id})
    end
  end

  def create_game( params)
    raise 'Names not unique' unless check_unique_names( params)
    g = PagodaGame.new( self, {id:params[:id]})
    g.update( params)
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

  def scan( id)
    PagodaScan.new( self, get( 'scan', :id, id.to_i)[0])
  end

  def scans
    selected = []
    @database.select( 'scan') do |rec|
      s = PagodaScan.new( self, rec)
      selected << s if (! block_given?) || (yield s)
    end
    selected
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

  def insert( table_name, table_rec)
    @database.insert( table_name, table_rec)
  end

  def keys( id)
    @names.keys(id)
  end

  def lookup( name)
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