require 'minitest/autorun'
require_relative '../../ruby/file_database'

class DatabaseTest < Minitest::Test
  class TestListener
    def initialize
      @table  = nil
      @action = nil
      @value  = nil
    end

    def assert_equal( expected, got)
      raise "Expected [#{expected}] got [#{got}]" unless expected == got
    end

    def expected(name, action, value)
      assert_equal @table,  name
      assert_equal @action, action
      assert_equal @value,  value
      @table  = nil
      @action = nil
      @value  = nil
    end

    def record_inserted(name, record)
      raise 'Unexpected called' if @action
      @table  = name
      @action = 'insert'
      @value  = record[:value]
    end

    def record_deleted(name, record)
      raise 'Unexpected called' if @action
      @table  = name
      @action = 'delete'
      @value  = record[:value]
    end
  end

  def ends_with( f, text)
    file_text = IO.read( @dir + '/' + f)
    assert_equal text, file_text.chomp[-text.size..-1]
  end

  def load_database
    FileDatabase.new( @dir)
  end

  def setup
    @dir = '/tmp/pagoda_database_test'
    unless File.exist?( @dir)
      Dir.mkdir( @dir)
    end
    to_delete = []
    Dir.entries( @dir).each do |f|
      to_delete << f if /\.(tsv|txt)$/ =~ f
    end
    to_delete.each {|f| File.delete( @dir + '/' + f)}
  end

  def teardown
    # Do nothing
  end

  def write( f, text)
    raise "File #{f} already exists" if File.exist?( @dir + '/' + f)
    File.open( @dir + '/' + f, 'w') {|io| io.puts text}
  end

  def test_bad_timestamp
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "timestamp\tdata\t111"
    ok = true
    begin
      load_database
      ok = false
    rescue Exception => bang
      ok = (/Wrong timestamp/ =~ bang.message)
    end
    assert ! ok.nil?
  end

  def test_boolean
    write 'data.tsv', "id\tvalid\n1\tY"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t2\tN\nEND"
    db = load_database
    get = db.get( 'data', :id, 1)[0]
    assert_equal( true, get[:valid])
    get = db.get( 'data', :valid, false)[0]
    assert_equal( 2, get[:id])
  end

  def test_broken_transaction_ignored
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred"
    db = load_database
    assert_equal 0, db.count('data')
  end

  # def test_combinations
  #   write 'data.tsv', "id\tname"
  #   db = load_database
  #   db.start_transaction
  #   db.insert( 'data', {id:1, name:'fred'})
  #   db.insert( 'data', {id:2, name:'bill'})
  #   db.insert( 'data', {id:3, name:'fred'})
  #   combs = db.combinations( 'data', :name, :id)
  #   assert_equal 2, combs.size
  #   assert_equal 2, combs['fred'].size
  #   assert_equal 2, combs['bill'].keys[0]
  # end

  def test_clean_missing
    write 'data1.tsv', "id\tkey\n1\tApple\n2\tBanana"
    write 'data2.tsv', "key\tname\nGreen\tApple\nBlack\tBlackberry"
    db = load_database
    db.clean_missing( 'data2', :name, 'data1', :key)
    missed = db.missing( 'data2', :name, 'data1', :key)
    assert_equal 0, missed.size
  end

  def test_count
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    assert_equal 1, db.count('data')
  end

  def test_integer
    write 'data.tsv', "id\tname\n1\tfred"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t2\tbill\nEND"
    db = load_database
    get = db.get( 'data', :id, 1)[0]
    assert_equal( 1, get[:id])
    get = db.get( 'data', :name, 'bill')[0]
    assert_equal( 2, get[:id])
  end

  def test_delete
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    assert_equal 1, db.count('data')
    db.start_transaction
    db.delete( 'data', :id, 1)
    db.end_transaction
    assert_equal 0, db.count('data')
    ends_with 'transaction.txt', "\nDELETE\tdata\tid\t1\nEND"
  end

  def test_get
    write 'data.tsv', "id\tname"
    db = load_database
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.end_transaction
    got = false
    db.get( 'data', :id, 1) do |rec|
      got = true if rec[:name] == 'fred'
    end
    assert ! got.nil?
  end

  def test_has
    write 'data.tsv', "id\tname"
    db = load_database
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.end_transaction
    assert db.has?( 'data', :name, 'fred')
    assert ! db.has?( 'data', :name, 'bill')
  end

  def test_index_delete
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    assert_equal 1, db.get('data', :name, 'fred').size
    db.start_transaction
    db.delete( 'data', :name, 'fred')
    db.end_transaction
    assert_equal 0, db.count('data')
    assert_equal 0, db.get('data', :name, 'fred').size
  end

  def test_index_get
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nINSERT\tdata\t1\tbill\nEND"
    db = load_database
    assert_equal 2, db.get('data', :id, 1).size
    assert_equal 1, db.get('data', :name, 'fred').size
    db.start_transaction
    db.delete( 'data', :name, 'fred')
    db.end_transaction
    assert_equal 1, db.count('data')
    assert_equal 1, db.get('data', :name, 'bill').size
  end

  def test_insert
    write 'data.tsv', "id\tname"
    db = load_database
    assert_equal 0, db.count('data')
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.end_transaction
    assert_equal 1, db.count('data')
    ends_with 'transaction.txt', "\nINSERT\tdata\t1\tfred\nEND"
  end

  def test_insert_unknown_fields
    write 'data.tsv', "id\tname"
    db = load_database
    ok = true
    begin
      db.start_transaction
      db.insert( 'data', {id:1, surname:'threepwood'})
      db.end_transaction
      ok = false
    rescue Exception => bang
      ok = (/Unknown key/ =~ bang.message)
    end
    assert ok
  end

  def test_listener
    write 'data.tsv', "id\tvalue"
    listener = TestListener.new
    db = load_database
    db.start_transaction
    db.insert( 'data', {id:1, value:'fred1'})
    db.add_listener 'data', listener
    listener.expected 'data', 'insert', 'fred1'
    db.insert( 'data', {id:2, value:'fred2'})
    listener.expected 'data', 'insert', 'fred2'
    db.delete( 'data', :id, 1)
    listener.expected 'data', 'delete', 'fred1'
    db.end_transaction
  end

  def test_max_value
    write 'data.tsv', "id\tyear"
    db = load_database
    assert_equal 1, db.next_value( 'data', :id)
    db.start_transaction
    db.insert( 'data', {id:5, year:7})
    db.end_transaction
    assert_equal 7, db.max_value( 'data', :year)
  end

  def test_missing
    write 'data1.tsv', "id\tkey\n1\tApple\n2\tBanana"
    write 'data2.tsv', "key\tname\nGreen\tApple\nBlack\tBlackberry"
    db = load_database
    missed = db.missing( 'data2', :name, 'data1', :key)
    assert_equal 1, missed.size
    assert_equal 'Blackberry', missed[0]
  end

  def test_next_value
    write 'data.tsv', "id\tname"
    db = load_database
    assert_equal 1, db.next_value( 'data', :id)
    db.start_transaction
    db.insert( 'data', {id:5, name:'fred'})
    db.end_transaction
    assert_equal 6, db.next_value( 'data', :id)
  end

  def test_rebuild
    write 'data.tsv', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    db.rebuild
    ends_with( 'data.tsv', "id\tname\n1\tfred")
    assert ! File.exist?( @dir + '/transaction.txt')
  end

  def test_select
    write 'data.tsv', "id\tname"
    db = load_database
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.end_transaction
    got = false
    rows = db.select( 'data') do |rec|
      assert 'fred', rec[:name]
      got = true
    end
    assert ! got.nil?
    assert 1, rows.size
    assert 'fred', rows[0][:name]
  end

  def test_transaction_delete
    write 'data.tsv', "id\tname\n1\tfred"
    write 'transaction.txt', "BEGIN\nDELETE\tdata\tid\t1\nEND"
    db = load_database
    assert_equal 0, db.count( 'data')
  end

  def test_unique
    write 'data.tsv', "id\tname"
    db = load_database
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.insert( 'data', {id:2, name:'bill'})
    db.insert( 'data', {id:3, name:'fred'})
    names = db.unique( 'data', :name)
    assert_equal 2, names.size
    assert_equal 'bill', names[0]
    assert_equal 'fred', names[1]
  end
end