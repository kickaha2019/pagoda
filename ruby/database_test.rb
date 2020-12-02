require 'minitest/autorun'
require_relative 'database'

class DatabaseTest < Minitest::Test
  def ends_with( f, text)
    file_text = IO.read( @dir + '/' + f)
    assert_equal text, file_text.chomp[-text.size..-1]
  end

  def load_database
    Database.new( @dir)
  end

  def setup
    @dir = '/tmp/pagoda_database_test'
    unless File.exist?( @dir)
      Dir.mkdir( @dir)
    end
    to_delete = []
    Dir.entries( @dir).each do |f|
      to_delete << f if /\.txt$/ =~ f
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
    write 'data.txt', "id\tname"
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

  def test_broken_transaction_ignored
    write 'data.txt', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred"
    db = load_database
    assert_equal 0, db.count('data')
  end

  def test_count
    write 'data.txt', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    assert_equal 1, db.count('data')
  end

  def test_delete
    write 'data.txt', "id\tname"
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
    write 'data.txt', "id\tname"
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

  def test_index_delete
    write 'data.txt', "id\tname"
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
    write 'data.txt', "id\tname"
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
    write 'data.txt', "id\tname"
    db = load_database
    assert_equal 0, db.count('data')
    db.start_transaction
    db.insert( 'data', {id:1, name:'fred'})
    db.end_transaction
    assert_equal 1, db.count('data')
    ends_with 'transaction.txt', "\nINSERT\tdata\t1\tfred\nEND"
  end

  def test_insert_unknown_fields
    write 'data.txt', "id\tname"
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

  def test_join
    write 'data1.txt', "id\tkey"
    write 'data2.txt', "key\tname"
    db = load_database
    db.join( 'data1', :name, :key, 'data2', :key)
    db.start_transaction
    db.insert( 'data1', {id:1, key:'F1'})
    db.insert( 'data2', {key:'F1', name:'fred'})
    db.end_transaction

    found = false
    db.select( 'data1') do |rec|
      assert_equal 1, rec[:name].size
      assert_equal 'fred', rec[:name][0][:name]
      found = true
    end
    assert found
  end

  def test_rebuild
    write 'data.txt', "id\tname"
    write 'transaction.txt', "BEGIN\nINSERT\tdata\t1\tfred\nEND"
    db = load_database
    db.rebuild
    ends_with( 'data.txt', "id\tname\n1\tfred")
    assert ! File.exist?( @dir + '/transaction.txt')
  end

  def test_transaction_delete
    write 'data.txt', "id\tname\n1\tfred"
    write 'transaction.txt', "BEGIN\nDELETE\tdata\tid\t1\nEND"
    db = load_database
    assert_equal 0, db.count( 'data')
  end

  def test_unique
    write 'data.txt', "id\tname"
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