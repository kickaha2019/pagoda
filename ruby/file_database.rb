# frozen_string_literal: true

require_relative 'database'

class FileDatabase < Database
  def initialize( dir)
    super()
    @dir    = dir

    Dir.entries( dir).each do |f|
      if m = /^(.*)\.tsv$/.match( f)
        add_table(load_table( m[1], dir + '/' + f))
        #        @tables[m[1]] = Table.new( dir + '/' + f)
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

  def delete( table_name, column_name, column_value)
    super
    @transactions.puts "DELETE\t#{table_name}\t#{column_name}\t#{column_value.to_s.gsub( /[\t\r\n]/, ' ')}"
  end

  def end_transaction
    @transactions.puts 'END'
    @transactions.close
    @transactions = nil
  end

  def insert( table_name, record)
    fields = @tables[table_name].fields( record)
    @transactions.puts "INSERT\t" + table_name + "\t" + fields.collect {|v| v.to_s.gsub( /[\t\r\n]/, ' ')}.join( "\t")
    @tables[table_name].insert( * fields)
  end

  def load_table(name, path)
    lines   = IO.readlines( path).collect {|line| line.chomp}
    columns = lines[0].split( "\t").collect {|name| name.to_sym}
    data    = lines[1..-1].collect do |line|
      line.split( "\t").collect {|v| (v.strip == '') ? nil : v.strip}
    end
    Table.new(name, columns, data)
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
    if File.exist?( @transactions_file)
      @tables.each_pair do |name, table|
        table.save( @dir + '/' + name + '.tsv')
      end

      File.delete( @transactions_file)
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
end