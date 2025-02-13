# frozen_string_literal: true
require 'sqlite3'
require_relative 'common'

class SqliteDatabase
  include Common

  def initialize( path)
    @path      = path
    @sqlite    = SQLite3::Database.new(path)
    @listeners = Hash.new { |hash, key| hash[key] = [] }
    #    @sqlite.journal_mode='wal'
    @sqlite.locking_mode='exclusive'
    # p ['journal_mode', @sqlite.journal_mode]
    # p ['locking_mode', @sqlite.locking_mode]
    # p ['synchronous', @sqlite.synchronous]
    # p ['temp_store', @sqlite.temp_store]
    # p ['wal_checkpoint', @sqlite.wal_checkpoint]

    # if File.exist?(path + '.log')
    #   load(IO.read(path + '.log'))
    #   File.delete(path + '.log') unless log
    # end
    #
    # @logging     = log ? File.open(path + '.log', 'a') : nil
    # @transaction = []
  end

  def add_listener(name, listener)
    @listeners[name] << listener
    select(name) do |record|
      listener.record_inserted name, record
    end
  end

  def close
    @sqlite.close
  end

  def count( table_name)
    @sqlite.execute( "SELECT count(*) FROM #{table_name}")[0][0]
  end

  def delete( table_name, column_name, column_value)
    raise 'Not inside transaction' unless @sqlite.transaction_active?

    if @listeners[table_name].any?
      get(table_name, column_name, column_value).each do |record|
        @listeners[table_name].each do |listener|
          listener.record_deleted(table_name, record)
        end
      end
    end

    @sqlite.execute("delete from #{table_name} where #{to_word(column_name)} = ?",
                    [encode(column_value)])
    # sql = "delete from #{table_name} where #{to_word(column_name)} = " +
    #       encode2(column_value)
    # @sqlite.execute(sql)
    #    @transaction << sql
  end

  def decode(type, value)
    case type
    when :boolean
      (value == 1)
    else
      value
    end
  end

  def encode(value)
    case value
    when Array
      value.collect { |v| encode(v) }
    when FalseClass
      0
    when TrueClass
      1
    else
      value
    end
  end

  def end_transaction
    raise 'Not inside transaction' unless @sqlite.transaction_active?
    @sqlite.commit
    # if @logging
    #   @logging.puts(@transaction.join(";\n") + ';')
    #   @logging.flush
    # end
    # @transaction = []
  end

  def get( table_name, column_name, column_value)
    got = []
    results = @sqlite.query( "select * from #{table_name} where #{to_word(column_name)} = ?",
                             [encode(column_value)])
    row    = results.next
    while row do
      record = {}
      results.columns.each_index do |i|
        column = results.columns[i].to_sym
        record[column] = decode(type_for_name(column), row[i])
      end
      yield record if block_given?
      got << record
      row =  results.next
    end

    results.close
    got
  end

  def has?( table_name, column_name, column_value)
    get( table_name, column_name, column_value).size > 0
  end

  def insert( table_name, record)
    raise 'Not inside transaction' unless @sqlite.transaction_active?
    statement = "insert into #{table_name} ("
    keys      = record.keys.collect {|key| to_word(key)}
    places    = record.keys.collect {|_| '?'}
    @sqlite.execute( statement + keys.join(',') + ') values (' + places.join(',') + ')',
                     encode(record.values))
    # statement = ["insert into #{table_name} ("]
    # keys      = record.keys.collect {|key| to_word(key)}
    # statement << keys.join(',')
    # statement << ') values ('
    # places    = record.keys.collect {|key| encode2(record[key])}
    # statement << places.join(',')
    # statement << ')'
    # sql       = statement.join('')
    # @sqlite.execute(sql)
    #@transaction << sql

    @listeners[table_name].each do |listener|
      listener.record_inserted(table_name, record)
    end

    record
  end

  def load(sql)
    @sqlite.execute_batch(sql)
  end

  def max_value( table_name, column_name)
    results = @sqlite.query( "SELECT max(#{to_word(column_name)}) FROM #{table_name}")
    value   = results.next[0]
    results.close
    value.nil? ? 0 : value
  end

  def next_value( table_name, column_name)
    max_value(table_name, column_name) + 1
  end

  def reopen
    @sqlite = SQLite3::Database.new(@path)
  end

  def to_word( symbol)
    ([:index, :alias].include? symbol) ? "'#{symbol}'" : symbol.to_s
  end

  def select( table_name)
    got = []
    results = @sqlite.query( "select * from #{table_name}")
    row     = results.next
    while row do
      record = {}
      results.columns.each_index do |i|
        column = results.columns[i].to_sym
        record[column] = decode(type_for_name(column), row[i])
      end
      got << record if yield record
      row =  results.next
    end

    results.close
    got
  end

  def start_transaction
    @sqlite.rollback if @sqlite.transaction_active?
    @sqlite.transaction(:immediate)
    #@transaction = []
  end

  def unique( table_name, column_name)
    got = []
    results = @sqlite.query( "select #{to_word(column_name)} from #{table_name}")
    row     = results.next
    while row do
      got << decode(type_for_name(column_name), row[0])
      row =  results.next
    end

    results.close
    got.uniq.sort
  end

  def update( table_name, column_name, column_value, record)
    raise 'Not inside transaction' unless @sqlite.transaction_active?

    if @listeners[table_name].any?
      get(table_name, column_name, column_value).each do |record|
        @listeners[table_name].each do |listener|
          listener.record_deleted(table_name, record)
        end
      end
    end

    statement = ["update #{table_name} set"]
    separator = ''
    values    = []

    record.each_pair do |name, value|
      if name == column_name
        if column_value != record[column_name]
          raise 'Updating key field'
        end
      else
        statement << "#{separator}'#{to_word(name)}' = ?"
        separator = ','
        values << value
      end
    end
    statement << "where #{to_word(column_name)} = ?"
    values << column_value

    @sqlite.execute(statement.join(' '), encode(values))
    #@transaction << sql

    if @listeners[table_name].any?
      get(table_name, column_name, column_value).each do |record|
        @listeners[table_name].each do |listener|
          listener.record_inserted(table_name, record)
        end
      end
    end
  end
end