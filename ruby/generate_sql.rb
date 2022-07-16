require_relative 'pagoda'

class GenerateSQL
  def initialize( dir)
    @pagoda  = Pagoda.new( dir)
    @indexes = 0
  end

  def alias_fields
    {id:         'integer not null',
     name:       'varchar(120) not null',
     sort_name:  'varchar(120)',
     hide:       'varchar(1)'}
  end

  def collate_fields
    {id:         'integer not null',
     link:       'integer not null',
     rank:       'integer not null'}
  end

  def create_index( table_name, index_fields, io)
    io.puts "create index #{table_name}#{@indexes} on #{table_name} (#{index_fields});"
    @indexes += 1
  end

  def create_table( table_name, table_fields, io)
    io.puts "create table `#{table_name}`"
    separ = '('
    table_fields.each_pair do |k,v|
      io.puts "#{separ}`#{k}` #{v}"
      separ = ','
    end
    io.puts ');'
  end

  def drop_table( table_name, io)
    io.puts "drop table if exists `#{table_name}`;"
  end

  def game_fields
    {id:         'integer not null',
     name:       'varchar(120) not null',
     sort_name:  'varchar(120)',
     is_group:   'varchar(1)',
     group_id:   'integer',
     group_name: 'varchar(120)',
     game_type:  'varchar(1)',
     year:       'integer',
     developer:  'text',
     publisher:  'text',
     mac:        'varchar(1)',
     pc:         'varchar(1)',
     web:        'varchar(1)',
     console:    'varchar(1)',
     phone:      'varchar(1)',
     tablet:     'varchar(1)'}
  end

  def generate( path)
    File.open( path, 'w') do |io|
      drop_table( 'temp', io);
      create_table( 'temp', game_fields, io)
      load_table( 'temp', game_fields, @pagoda.games, io)
      primary_key( 'temp', 'id', io)
      drop_table( 'pagoda_game', io)
      rename_table( 'temp', 'pagoda_game', io)
      create_index( 'pagoda_game', 'name', io)
      create_index( 'pagoda_game', 'group_name', io)

      create_table( 'temp', alias_fields, io)
      load_table( 'temp', alias_fields, @pagoda.aliases, io)
      drop_table( 'pagoda_alias', io)
      rename_table( 'temp', 'pagoda_alias', io)
      create_index( 'pagoda_alias', 'id', io)
      create_index( 'pagoda_alias', 'name', io)

      create_table( 'temp', collate_fields, io)
      load_table( 'temp', collate_fields, @pagoda.collations, io)
      primary_key( 'temp', 'link', io)
      drop_table( 'pagoda_collate', io)
      rename_table( 'temp', 'pagoda_collate', io)
      create_index( 'pagoda_collate', 'id', io)

      create_table( 'temp', scan_fields, io)
      load_table( 'temp', scan_fields, @pagoda.generate_links, io)
      primary_key( 'temp', 'id', io)
      drop_table( 'pagoda_scan', io)
      rename_table( 'temp', 'pagoda_scan', io)
      create_index( 'pagoda_scan', 'site, type', io)

      create_table( 'temp', metadata_fields, io)
      insert_curdate( 'temp', io)
      drop_table( 'pagoda_metadata', io)
      rename_table( 'temp', 'pagoda_metadata', io)

      drop_table( 'pagoda_bind', io)
    end
  end

  def insert_curdate( table_name, io)
    io.puts "insert into #{table_name} select curdate();"
  end

  def insert_value( type, value)
    # if /Birthday Adventures/ =~ value.to_s
    #   puts 'DEBUG100'
    # end
    return value.to_i if /^int/ =~ type
    els = " #{value} ".split( "'")
    edited = els.join( "\\'")[1..-2]

    if m = /\((\d+)\)/.match( type)
      if edited.size > m[1].to_i
        raise "Too long string: #{value}"
      end
    end

    "'#{edited}'"
  end

  def load_table( table_name, table_fields, data, io)
    io.puts "insert into `#{table_name}`"
    separ = 'values'
    data.each do |rec|
      next unless rec.generate?
      line = [separ]
      delim = '('
      table_fields.each_pair do |k,v|
        line << "#{delim}#{insert_value( v, rec.send(k))}"
        delim = ','
      end
      io.puts line.join('')
      separ = '),'
    end
    io.puts ');'
  end

  def metadata_fields
    {uploaded:   'date not null'}
  end

  def primary_key( table_name, field_name, io)
    io.puts "alter table `#{table_name}` add primary key (`#{field_name}`);"
  end

  def rename_table( from, to, io)
    io.puts "rename table `#{from}` to `#{to}`;"
  end

  def report
    types = Hash.new {|h,k| h[k] = 0}
    @pagoda.games do |g|
      types[g.game_type] += 1
    end
    types.each_pair do |k,v|
      puts "... Game type #{k} count #{v}"
    end
  end

  def scan_fields
    {id:    'integer not null',
     site:  'varchar(100) not null',
     type:  'varchar(100) not null',
     name:  'text not null',
     label: 'text not null',
     url:   'text not null'}
  end
end

gs = GenerateSQL.new( ARGV[0])
gs.generate( ARGV[1])
gs.report