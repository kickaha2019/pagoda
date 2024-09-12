class Table
  def initialize( path)
    @name    = path.split('/')[-1].split('.')[0]
    lines    = IO.readlines( path).collect {|line| line.chomp}
    @columns = lines[0].split( "\t").collect {|name| name.to_sym}
    @joins   = {}
    @types   = Hash.new {|h,k| h[k] = :to_s}

    data = lines[1..-1].collect do |line|
      line.split( "\t").collect {|v| (v.strip == '') ? nil : v.strip}
    end

    initialize_indexes( data)
  end

  def add_index( column_name)
    index  = @indexes[column_name] = Hash.new {|h1,k1| h1[k1] = []}
    colind = column_index( column_name)
    raise "Unknown column #{column_name} for #{@name}" if colind.nil?

    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        if row[colind].nil?
          if @types[column_name] == :to_i
            row[colind] = 0
          else
            p [@name, column_name, row]
            raise "No value for index column"
          end
        end
        index[row[colind]] << row
      end
    end
  end

  def coerce( column_name, column_value)
    return nil if column_value.nil?
    return nil if column_value.is_a?( String) && (column_value.strip == '')
    column_value.send( @types[ column_name])
  end

  def column_index( column_name)
    @columns.index( column_name)
  end

  # def combinations( * cols)
  #   map = {}
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       m = map
  #       cols.each do |col|
  #         v = row[column_index(col)]
  #         raise "Column value nil" if v.nil?
  #         if m.key?(v)
  #           m = m[v]
  #         else
  #           m = m[v] = {}
  #         end
  #       end
  #     end
  #   end
  #   map
  # end

  def declare_integer( column_name)
    @types[column_name] = :to_i
    colind = column_index( column_name)

    all_rows = []
    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        row[colind] = row[colind].to_i if row[colind]
        all_rows << row
      end
    end

    initialize_indexes( all_rows)
  end

  def delete( column_name, column_value)
    column_value = coerce( column_name, column_value)

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
      if @columns.index( key).nil?
        p @columns
        raise "Unknown key #{key}"
      end
    end
    @columns.collect {|name| record[name]}
  end

  def get( column_name, column_value)
    column_value = coerce( column_name, column_value)

    if @indexes[column_name].nil?
      add_index( column_name)
    end

    @indexes[column_name][column_value].each do |row|
      yield record( row)
    end
  end

  def initialize_indexes( data)
    @indexes = {}
    index = @indexes[@columns[0]] = Hash.new {|h1,k1| h1[k1] = []}
    data.each do |fields|
      index[fields[0]] << fields
    end
  end

  def insert( * row)
    @columns.each_index do |i|
      row[i] = coerce( @columns[i], row[i])
    end

    @indexes.each_pair do |index_column, index|
      colind = column_index( index_column)
      raise "No value for index column #{index_column}" if row[colind].nil?
      index[row[colind]] << row
    end
    record( row)
  end

  def next_value( column_name)
    colind    = column_index( column_name)
    max_value = 0

    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        max_value = row[colind] if row[colind] && row[colind].to_i > max_value
      end
    end

    max_value + 1
  end

  def record( fields)
    rec = {}
    fields.each_index {|i| rec[@columns[i]] = fields[i]}
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