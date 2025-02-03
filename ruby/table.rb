require_relative 'common'

class Table
  include Common
  attr_reader :name

  def initialize(name, columns, data)
    @name      = name
    @columns   = columns
    @joins     = {}
    @types     = {}
    columns.each do |column|
      @types[column] = type_for_name(column)
    end
    @listeners = []
    initialize_indexes( data)
  end

  def add_index( column_name)
    index  = @indexes[column_name] = Hash.new {|h1,k1| h1[k1] = []}
    colind = column_index( column_name)
    raise "Unknown column #{column_name} for #{@name}" if colind.nil?

    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        if row[colind].nil?
          p [@name, column_name, row]
          raise "No value for index column"
        end
        index[row[colind]] << row
      end
    end
  end

  def add_listener(listener)
    @indexes[@columns[0]].each_value do |rows|
      rows.each do |row|
        rec = record( row)
        listener.record_inserted @name, rec
      end
    end
    @listeners << listener
  end

  # def coerce( column_name, column_value)
  #   return nil if column_value.nil?
  #   return nil if column_value.is_a?( String) && (column_value.strip == '')
  #   column_value.send( @types[ column_name])
  # end

  def coerce_strings( row)
    row.each_index do |i|
      row[i] = coerce(@types[@columns[i]], row[i])
      # case @types[@columns[i]]
      # when :boolean
      #   row[i] = (row[i] == 'Y')
      # when :float
      #   row[i] = row[i].to_f
      # when :integer
      #   row[i] = row[i].to_i
      # when :nullable_string
      #   row[i] = row[i].nil? ? nil : (row[i].strip.empty? ? nil : row[i].strip)
      # else
      #   row[i] = row[i].strip
      # end
    end
    row
  end

  def column_index( column_name)
    @columns.index( column_name)
  end

  # def declare_boolean( column_name)
  #   @types[column_name] = :declare_boolean
  #   colind = column_index( column_name)
  #
  #   all_rows = []
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       row[colind] = (row[colind] == 'Y')
  #       all_rows << row
  #     end
  #   end
  #
  #   initialize_indexes( all_rows)
  # end
  #
  # def declare_float( column_name)
  #   @types[column_name] = :float
  #   colind = column_index( column_name)
  #
  #   all_rows = []
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       row[colind] = row[colind] ? row[colind].to_f : 0.0
  #       all_rows << row
  #     end
  #   end
  #
  #   initialize_indexes( all_rows)
  # end
  #
  # def declare_integer( column_name)
  #   @types[column_name] = :integer
  #   colind = column_index( column_name)
  #
  #   all_rows = []
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       row[colind] = row[colind] ? row[colind].to_i : 0
  #       all_rows << row
  #     end
  #   end
  #
  #   initialize_indexes( all_rows)
  # end
  #
  # def declare_not_null_string( column_name)
  #   @types[column_name] = :string
  #   colind = column_index( column_name)
  #
  #   all_rows = []
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       row[colind] = row[colind] ? row[colind] : ''
  #       all_rows << row
  #     end
  #   end
  #
  #   initialize_indexes( all_rows)
  # end
  #
  # def declare_nullable_integer( column_name)
  #   @types[column_name] = :nullable_integer
  #   colind = column_index( column_name)
  #
  #   all_rows = []
  #   @indexes[@columns[0]].each_value do |rows|
  #     rows.each do |row|
  #       row[colind] = row[colind] ? row[colind].to_i : nil
  #       all_rows << row
  #     end
  #   end
  #
  #   initialize_indexes( all_rows)
  # end

  def delete( column_name, column_value)
    validate_column_value(column_name, column_value)
    #column_value = coerce( column_name, column_value)

    if @indexes[column_name].nil?
      add_index( column_name)
    end

    to_delete = []
    @indexes[column_name][column_value].each do |row|
      to_delete << row
      @listeners.each do |listener|
        listener.record_deleted(@name, record(row))
      end
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

  def fields_as_strings( record)
    record.each_key do |key|
      if @columns.index( key).nil?
        p @columns
        raise "Unknown key #{key}"
      end
    end
    @columns.collect {|name| stringify( @types[name], record[name])}
  end

  def get( column_name, column_value)
    validate_column_value( column_name, column_value)

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
      validate_column_value(@columns[i], row[i])
    end

    rec = record(row)
    @listeners.each do |listener|
      listener.record_inserted(@name, rec)
    end

    @indexes.each_pair do |index_column, index|
      colind = column_index( index_column)
      raise "No value for index column #{index_column}" if row[colind].nil?
      index[row[colind]] << row
    end

    rec
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
          row.each_index do |i|
            row[i] = stringify(@types[@columns[i]], row[i])
          end
          io.puts row.join( "\t")
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

  def validate_column_value(column_name, column_value)
    case @types[column_name]
    when :boolean
      raise "Not a boolean value for #{column_name}" unless [nil, true, false].include?(column_value)
    when :float
      raise "Not a float value for #{column_name}" unless column_value.is_a?(Float)
    when :integer
      raise "Not an integer value for #{column_name}" unless column_value.is_a?(Integer)
    when :nullable_integer
      raise "Not an integer value for #{column_name}" unless column_value.nil? || column_value.is_a?(Integer)
    when :string
      raise "Not a string value for #{column_name}" unless column_value.is_a?(String)
    else
      raise "Bad value for column #{column_name}" unless column_value.nil? || column_value.is_a?(String)
    end
  end
end