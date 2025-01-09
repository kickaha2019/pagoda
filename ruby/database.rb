require 'json'
require_relative 'table'

class Database
  def initialize
    @tables = {}
  end

  def add_table(table)
    raise "Duplicate table: #{table.name}" unless @tables[table.name].nil?
    @tables[table.name] = table
  end

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

  def clean_missing_positive( table1, column1, table2, column2)
    start_transaction
    missed = missing_positive( table1, column1, table2, column2)
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
  end

  def end_transaction
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
    @tables[table_name].insert( * fields)
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

  def missing_positive( table1, column1, table2, column2)
    missed = []
    @tables[table1].select do |rec|
      value = rec[column1]
      next if value < 0
      unless has?( table2, column2, value)
        missed << value
      end
    end
    missed
  end

  def next_value( table_name, column_name)
    @tables[ table_name].next_value( column_name)
  end

  def select( table_name)
    @tables[table_name].select do |rec|
      yield rec
    end
  end

  def start_transaction
  end

  def unique( table_name, column_name)
    @tables[table_name].unique( column_name)
  end

  def update( table_name, column_name, value, record)
    delete( table_name, column_name, value) 
    insert( table_name, record)
  end
end