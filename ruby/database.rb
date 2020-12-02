require 'json'
require_relative 'table'

class Database
  def initialize( dir)
    @dir    = dir
    @tables = {}

    Dir.entries( dir).each do |f|
      if m = /^(.*)\.txt$/.match( f)
        if m[1] != 'transaction'
          @tables[m[1]] = Table.new( dir + '/' + f)
        end
      end
    end

    @transactions_file = dir + '/transaction.txt'
    begun = 0

    if File.exist?(@transactions_file)
      lines = IO.readlines(@transactions_file).collect {|line| line.chomp}
      lines.each_index do |i|
        if /^timestamp/ =~ lines[i]
          path = dir + '/' + lines[i].split("\t")[1] + '.txt'
          ts   = lines[i].split("\t")[2].to_i
          raise "Wrong timestamp for #{path}" if ts != File.mtime( path)
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

  def count( table_name)
    @tables[table_name].size
  end

  def delete( table_name, column_name, column_value)
    @tables[table_name].delete( column_name, column_value)
    @transactions.puts "DELETE\t#{table_name}\t#{column_name}\t#{column_value}"
  end

  def end_transaction
    @transactions.puts 'END'
    @transactions.flush
  end

  def get( table_name, column_name, column_value)
    got = []
    @tables[table_name].get( column_name, column_value) do |rec|
      got << rec
      yield rec if block_given?
    end
    got
  end

  def insert( table_name, record)
    fields = @tables[table_name].fields( record)
    @tables[table_name].insert( * fields)
    @transactions.puts "INSERT\t" + table_name + "\t" + fields.collect {|v| v.to_s}.join( "\t")
  end

  def join( from_table, join_name, from_column, to_table, to_column)
    @tables[from_table].join( join_name) do |rec|
      joins = []
      @tables[to_table].get( to_column, rec[from_column]) do |rec1|
        joins << rec1
      end
      joins
    end
  end

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

  def rebuild
    @tables.each_pair do |name, table|
      table.save( @dir + '/' + name + '.txt')
    end

    if @transactions
      @transactions.close
      @transactions = nil
      File.delete( @transactions_file)
    end
  end

  def select( table_name)
    @tables[table_name].select do |rec|
      yield rec
    end
  end

  def start_transaction
    unless @transactions
      File.open(@transactions_file, 'w') do |io|
        Dir.entries( @dir).each do |f|
          if m = /^(.*)\.txt$/.match( f)
            if m[1] != 'transaction'
              io.puts "timestamp\t#{m[1]}\t#{File.mtime( @dir + '/' + f)}"
            end
          end
        end
      end

      @transactions = File.open(@transactions_file, 'a+')
    end

    @transactions.puts 'BEGIN'
  end

  def unique( table_name, column_name)
    @tables[table_name].unique( column_name)
  end
end