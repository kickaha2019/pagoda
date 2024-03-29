require 'json'
require_relative 'table'

class Database
  def initialize( dir)
    @dir    = dir
    @tables = {}

    Dir.entries( dir).each do |f|
      if m = /^(.*)\.tsv$/.match( f)
        @tables[m[1]] = Table.new( dir + '/' + f)
      end
    end

    @transactions_file = dir + '/transaction.txt'
    begun = 0

    if File.exist?(@transactions_file)
      lines = IO.readlines(@transactions_file).collect {|line| line.chomp}
      lines.each_index do |i|
        if /^timestamp/ =~ lines[i]
          path = dir + '/' + lines[i].split("\t")[1] + '.tsv'
          ts   = lines[i].split("\t")[2].to_i
          raise "Wrong timestamp for #{path}" if ts != File.mtime( path).to_i
        end
        begun = i if 'BEGIN' == lines[i]
        if 'END' == lines[i]
          (begun+1...i).each do |j|
            load_transaction( lines[j].split("\t"))
          end
        end
      end

      @transactions = File.open(@transactions_file, 'a+')
    end
  end

  # def combinations( table_name, * columns)
  #   @tables[table_name].combinations( * columns)
  # end

  def clean_missing( table1, column1, table2, column2)
    start_transaction
    missed = missing( table1, column1, table2, column2)
    missed.each do |key|
      puts "... Cleaning #{table1} #{column1} #{key}"
      delete( table1, column1, key)
    end
    end_transaction
    missed
  end

  def count( table_name)
    @tables[table_name].size
  end

  def declare_integer( table_name, column_name)
    @tables[table_name].declare_integer( column_name)
  end

  def delete( table_name, column_name, column_value)
    @tables[table_name].delete( column_name, column_value)
    @transactions.puts "DELETE\t#{table_name}\t#{column_name}\t#{column_value.to_s.gsub( /[\t\r\n]/, ' ')}"
  end

  def end_transaction
    @transactions.puts 'END'
    @transactions.close
    @transactions = nil
  end

  def get( table_name, column_name, column_value)
    got = []
    @tables[table_name].get( column_name, column_value) do |rec|
      got << rec
      yield rec if block_given?
    end
    got
  end

  def has?( table_name, column_name, column_value)
    get( table_name, column_name, column_value).size > 0
  end

  def insert( table_name, record)
    fields = @tables[table_name].fields( record)
    @transactions.puts "INSERT\t" + table_name + "\t" + fields.collect {|v| v.to_s.gsub( /[\t\r\n]/, ' ')}.join( "\t")
    @tables[table_name].insert( * fields)
  end

  # def join( from_table, join_name, from_column, to_table, to_column)
  #   @tables[from_table].join( join_name) do |rec|
  #     joins = []
  #     @tables[to_table].get( to_column, rec[from_column]) do |rec1|
  #       joins << rec1
  #     end
  #     joins
  #   end
  # end

  def load_transaction( rec)
    table = @tables[rec[1]]
    raise "Unknown table: #{rec[1]}" unless table
    if rec[0] == 'DELETE'
      table.delete( rec[2].to_sym, rec[3])
    elsif rec[0] == 'INSERT'
      table.insert( * rec[2..-1])
    else
      raise "Unknown transaction: #{rec[0]}"
    end
  end

  def max_value( table_name, column_name)
    got = 0
    @tables[table_name].select do |rec|
      value = rec[column_name]
      got = value if value && value.is_a?( Integer) && (value > got)
    end
    got
  end

  def missing( table1, column1, table2, column2)
    missed = []
    @tables[table1].select do |rec|
      value = rec[column1]
      unless has?( table2, column2, value)
        missed << value
      end
    end
    missed
  end

  def next_value( table_name, column_name)
    @tables[ table_name].next_value( column_name)
  end

  def rebuild
    if File.exist?( @transactions_file)
      @tables.each_pair do |name, table|
        table.save( @dir + '/' + name + '.tsv')
      end

      File.delete( @transactions_file)
    end
  end

  def select( table_name)
    @tables[table_name].select do |rec|
      yield rec
    end
  end

  def start_transaction
    unless File.exist?( @transactions_file)
      File.open(@transactions_file, 'w') do |io|
        Dir.entries( @dir).each do |f|
          if m = /^(.*)\.tsv$/.match( f)
            io.puts "timestamp\t#{m[1]}\t#{File.mtime( @dir + '/' + f).to_i}"
          end
        end
      end
    end

    @transactions = File.open(@transactions_file, 'a+')
    @transactions.puts 'BEGIN'
  end

  def unique( table_name, column_name)
    @tables[table_name].unique( column_name)
  end
end