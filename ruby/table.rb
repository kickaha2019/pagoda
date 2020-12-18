class Table
  def initialize( path)
    @name    = path.split('/')[-1].split('.')[0]
    lines    = IO.readlines( path).collect {|line| line.chomp}
    @columns = lines[0].split( "\t").collect {|name| name.to_sym}
    @indexes = {}
    @joins   = {}

    index = @indexes[@columns[0]] = Hash.new {|h1,k1| h1[k1] = []}
    lines[1..-1].each do |line|
      fields = coerce_array( line.split( "\t"))
      index[fields[0]] << fields
    end
  end

  def add_index( column_name)
    index  = @indexes[column_name] = Hash.new {|h1,k1| h1[k1] = []}
    colind = column_index( column_name)

    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        raise "No value for index column" if row[colind].nil?
        index[row[colind]] << row
      end
    end
  end

  def coerce( value)
    if ! value.is_a?( String)
      value
    elsif /^(\-|)\d+$/ =~ value
      value.to_i
    elsif /^(\-|)(\d*)\.(\d*)$/ =~ value
      value.to_f
    else
      value
    end
  end

  def coerce_array( values)
    values.collect {|value| coerce( value)}
  end

  def column_index( column_name)
    @columns.index( column_name)
  end

  def combinations( * cols)
    map = {}
    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        m = map
        cols.each do |col|
          v = row[column_index(col)]
          raise "Column value nil" if v.nil?
          if m.key?(v)
            m = m[v]
          else
            m = m[v] = {}
          end
        end
      end
    end
    map
  end

  def delete( column_name, column_value)
    column_value = coerce( column_value)

    if @indexes[column_name].nil?
      add_index( column_name)
    end

    to_delete = []
    @indexes[column_name][column_value].each do |row|
      to_delete << row
    end

    to_delete.each do |row|
      @indexes.each_pair do |index_column, index|
        colind = column_index( index_column)
        raise "No value for index column" if row[colind].nil?
        index[row[colind]].select! {|ir| ir != row}
        index.delete( row[colind]) if index[row[colind]].size == 0
      end
    end
  end

  def fields( record)
    record.each_key do |key|
      raise "Unknown key #{key}" if @columns.index( key).nil?
    end
    @columns.collect {|name| record[name]}
  end

  def get( column_name, value)
    if @indexes[column_name].nil?
      add_index( column_name)
    end

    @indexes[column_name][value].each do |row|
      yield record( row)
    end
  end

  def insert( * fields)
    row = coerce_array( fields)
    @indexes.each_pair do |index_column, index|
      colind = column_index( index_column)
      raise "No value for index column #{index_column}" if row[colind].nil?
      index[row[colind]] << row
    end
    record( row)
  end

  def join( join_name, &block)
    @joins[join_name] = block
  end

  def next_value( column_name)
    colind    = column_index( column_name)
    max_value = 0

    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        max_value = row[colind] if row[colind] && row[colind] > max_value
      end
    end

    max_value + 1
  end

  def record( fields)
    rec = {}
    fields.each_index {|i| rec[@columns[i]] = fields[i]}
    @joins.each_pair do |name,block|
      rec[name] = block.call( rec)
    end
    rec
  end

  def save( path)
    File.open( path, 'w') do |io|
      io.puts @columns.join( "\t")
      @indexes[@columns[0]].each_value do |rows|
        rows.each do |row|
          io.puts row.collect {|v| v.to_s}.join( "\t")
        end
      end
    end
  end

  def select
    selected = []
    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        rec = record( row)
        selected << rec if yield rec
      end
    end
    selected
  end

  def size
    size = 0
    @indexes[@columns[0]].each_value do |rows|
      size += rows.size
    end
    size
  end

  def unique( column_name)
    if @indexes[column_name].nil?
      add_index( column_name)
    end

    @indexes[column_name].keys.sort
  end
end