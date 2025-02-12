require 'minitest/autorun'
require_relative '../../ruby/sqlite_database'

class SqliteDatabaseTest < Minitest::Test
  PATH = '/tmp/pagoda_database_test.sqlite'.freeze

  class TestListener
    def initialize
      @table  = []
      @action = []
      @value  = []
    end

    def assert_equal( got, expected)
      raise "Expected [#{expected}] got [#{got}]" unless expected == got
    end

    def expected(name, action, value)
      assert_equal @table[0],  name
      assert_equal @action[0], action
      assert_equal @value[0],  value
      @table  = @table[1..-1]
      @action = @action[1..-1]
      @value  = @value[1..-1]
    end

    def expected_none
      assert_equal 0, @table.size
    end

    def record_inserted(name, record)
      @table  << name
      @action << 'insert'
      @value  << record[:value]
    end

    def record_deleted(name, record)
      @table  << name
      @action << 'delete'
      @value  << record[:value]
    end
  end

  def setup
    File.delete( PATH ) if File.exist?( PATH )
    File.delete( PATH+'.log' ) if File.exist?( PATH+'.log' )
    @database = SqliteDatabase.new(PATH)
  end

  def reopen(log=false)
    @database.close
    @database = SqliteDatabase.new(PATH)
  end

  def teardown
    # Do nothing
  end

  # def read_log
  #   IO.read( PATH+'.log' ).strip
  # end
  #
  # def write_log(text)
  #   File.open( PATH+'.log', 'w' ) do |f|
  #     f.puts text
  #   end
  # end

  def test_boolean
    @database.load <<TEST_BOOLEAN
create table data (id int PRIMARY KEY, valid int);
insert into data (id, valid) values (1, 1);
insert into data (id, valid) values (2, 0);
TEST_BOOLEAN
    get = @database.get( 'data', :id, 1)[0]
    assert_equal( true, get[:valid])
    get = @database.get( 'data', :valid, false)[0]
    assert_equal( 2, get[:id])
  end

  def test_count
    @database.load <<TEST_COUNT
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
TEST_COUNT
    assert_equal 1, @database.count('data')
  end

  def test_delete
    listener = TestListener.new
    @database.load <<TEST_DELETE
create table data (id int PRIMARY KEY, value text);
insert into data (id, value) values (1, 'fred1');
TEST_DELETE
    @database.add_listener 'data', listener
    listener.expected 'data', 'insert', 'fred1'
    assert_equal 1, @database.count('data')
    @database.start_transaction
    @database.delete( 'data', :id, 1)
    @database.end_transaction
    assert_equal 0, @database.count('data')
    listener.expected 'data', 'delete', 'fred1'
    listener.expected_none
  end

#   def test_delete_log1
#     reopen(true)
#     @database.load <<TEST_DELETE
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred1');
# TEST_DELETE
#     @database.start_transaction
#     @database.delete( 'data', :id, 1)
#     @database.delete( 'data', :id, 2)
#     @database.end_transaction
#     assert_equal "delete from data where id = 1;\ndelete from data where id = 2;", read_log
#   end
#
#   def test_delete_log2
#     @database.load <<TEST_DELETE
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred');
# insert into data (id, value) values (2, 'bill');
# TEST_DELETE
#     write_log "delete from data where id = 1; delete from data where id = 2;"
#     reopen
#     assert_equal 0, @database.count('data')
#   end

  def test_get
    @database.load <<TEST_GET
create table data (id int PRIMARY KEY, name text);
TEST_GET
    @database.start_transaction
    @database.insert( 'data', {id:1, name:'fred'})
    @database.end_transaction
    got = false
    @database.get( 'data', :id, 1) do |rec|
      got = true if rec[:name] == 'fred'
    end
    assert ! got.nil?
  end

  def test_has
    @database.load <<TEST_HAS
create table data (id int PRIMARY KEY, name text);
TEST_HAS
    assert ! @database.has?( 'data', :name, 'fred')
    @database.start_transaction
    @database.insert( 'data', {id:1, name:'fred'})
    @database.end_transaction
    assert @database.has?( 'data', :name, 'fred')
  end

  def test_insert
    listener = TestListener.new
    @database.load <<TEST_INSERT
create table data (id int PRIMARY KEY, value text);
insert into data (id, value) values (1, 'fred');
TEST_INSERT
    @database.add_listener 'data', listener
    listener.expected 'data', 'insert', 'fred'
    assert_equal 1, @database.count('data')
    @database.start_transaction
    @database.insert( 'data', {id:2, value:'bill'})
    @database.end_transaction
    assert_equal 2, @database.count('data')
    listener.expected 'data', 'insert', 'bill'
    listener.expected_none
  end

#   def test_insert_log1
#     reopen(true)
#     @database.load <<TEST_INSERT
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred');
# TEST_INSERT
#     @database.start_transaction
#     @database.insert( 'data', {id:2, value:'bill'})
#     @database.end_transaction
#     assert_equal "insert into data (id,value) values (2,'bill');", read_log
#   end
#
#   def test_insert_log2
#     @database.load <<TEST_DELETE
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred');
# TEST_DELETE
#     write_log "insert into data (id,value) values (2,'bill');"
#     reopen
#     assert_equal 2, @database.count('data')
#   end

  def test_insert_unknown_fields
    @database.load <<TEST_INSERT_UNKNOWN_FIELDS
create table data (id int PRIMARY KEY, value text);
insert into data (id, value) values (1, 'fred');
TEST_INSERT_UNKNOWN_FIELDS
    ok = true
    begin
      @database.start_transaction
      @database.insert( 'data', {id:1, surname:'threepwood'})
      @database.end_transaction
      ok = false
    rescue Exception => bang
      ok = (/has no column named/ =~ bang.message)
    end
    assert ok
  end

  def test_integer
    @database.load <<TEST_INTEGER
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
insert into data (id, name) values (2, 'bill');
TEST_INTEGER
    get = @database.get( 'data', :id, 1)[0]
    assert_equal( 1, get[:id])
    get = @database.get( 'data', :name, 'bill')[0]
    assert_equal( 2, get[:id])
  end

  def test_max_value
    @database.load <<TEST_MAX_VALUE
create table data (id int PRIMARY KEY, year int);
TEST_MAX_VALUE
    assert_equal 0, @database.max_value( 'data', :year)
    @database.start_transaction
    @database.insert( 'data', {id:5, year:7})
    @database.end_transaction
    assert_equal 7, @database.max_value( 'data', :year)
  end

  def test_next_value
    @database.load <<TEST_NEXT_VALUE
create table data (id int PRIMARY KEY, name text);
TEST_NEXT_VALUE
    assert_equal 1, @database.next_value( 'data', :id)
    @database.start_transaction
    @database.insert( 'data', {id:5, name:'fred'})
    @database.end_transaction
    assert_equal 6, @database.next_value( 'data', :id)
  end

  def test_select
    @database.load <<TEST_SELECT
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
TEST_SELECT
    got = false
    rows = @database.select( 'data') do |rec|
      assert 'fred', rec[:name]
      got = true
    end
    assert got
    assert 1, rows.size
    assert 'fred', rows[0][:name]
  end

  def test_unique
    @database.load <<TEST_UNIQUE
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
insert into data (id, name) values (2, 'bill');
insert into data (id, name) values (3, 'fred');
TEST_UNIQUE
    names = @database.unique( 'data', :name)
    assert_equal 2, names.size
    assert_equal 'bill', names[0]
    assert_equal 'fred', names[1]
  end

  def test_update_ok
    listener = TestListener.new
    @database.load <<TEST_UPDATE_OK
create table data (id int PRIMARY KEY, value text);
insert into data (id, value) values (1, 'fred');
TEST_UPDATE_OK
    @database.add_listener 'data', listener
    listener.expected 'data', 'insert', 'fred'
    @database.start_transaction
    @database.update('data', :id, 1,{value:'bill'})
    @database.end_transaction
    listener.expected 'data', 'delete', 'fred'
    listener.expected 'data', 'insert', 'bill'
  end

#   def test_update_log1
#     reopen(true)
#     @database.load <<TEST_UPDATE_OK
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred');
# TEST_UPDATE_OK
#     @database.start_transaction
#     @database.update('data', :id, 1,{value:'bill'})
#     @database.end_transaction
#     assert_equal "update data set 'value' = 'bill' where id = 1;", read_log
#   end
#
#   def test_update_log2
#     @database.load <<TEST_UPDATE_OK
# create table data (id int PRIMARY KEY, value text);
# insert into data (id, value) values (1, 'fred');
# TEST_UPDATE_OK
#     write_log "update data set 'value' = 'bill' where id = 1;"
#     reopen
#     assert @database.has?('data', :value, 'bill')
#   end

  def test_update_key_error
    @database.load <<TEST_UPDATE_KEY_ERROR
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
TEST_UPDATE_KEY_ERROR
    ok = true
    begin
      @database.start_transaction
      @database.update( 'data', :id, 1, {id:2, name:'threepwood'})
      @database.end_transaction
      ok = false
    rescue Exception => bang
      ok = (/Updating key field/ =~ bang.message)
    end
    assert ok
  end

  def test_update_unknown_fields
    @database.load <<TEST_UPDATE_KEY_ERROR
create table data (id int PRIMARY KEY, name text);
insert into data (id, name) values (1, 'fred');
TEST_UPDATE_KEY_ERROR
    ok = true
    begin
      @database.start_transaction
      @database.update( 'data', :id, 1, {surname:'threepwood'})
      @database.end_transaction
      ok = false
    rescue Exception => bang
      ok = (/no such column:/ =~ bang.message)
    end
    assert ok
  end
end