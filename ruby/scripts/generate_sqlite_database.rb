require 'json'
require 'sqlite3'
require_relative '../pagoda'

class GenerateSqliteDatabase
  def initialize( dir, cache)
    @dir    = dir
    @pagoda = Pagoda.release( dir, cache)
    @pagoda.clean
    @pagoda.clean_cache
    @binds    = []
    @on_error = nil
    @errors   = []
  end

  def bind( *arguments)
    @binds = arguments
  end

  def check_errors(stage)
    unless @errors.empty?
      puts "*** #{@errors} errors"
      raise @errors[-1]
    end
    @pagoda.log(stage)
  end

  def close
    @sqlite3.close
    check_errors 'Completed'
  end

  def create_database(database_file)
    raise "Already exists" if File.exist?(database_file)
    @sqlite3 = SQLite3::Database.new(database_file)

    statement = ''
    IO.readlines(@dir + '/create_database.sql').each do |line|
      statement = (statement + ' ' + line).strip
      if /;$/ =~ line
        on_error statement
        execute statement
        statement = ''
      end
    end

    unless statement.empty?
      raise statement
    end

    check_errors 'Database created'
  end

  def execute( statement=nil)
    begin
      if statement.nil?
        @prepared.execute @binds
      else
        @sqlite3.execute statement, @binds
      end
    rescue StandardError => e
      if @on_error
        p @on_error
        @on_error = nil
        @errors << e
        raise
      else
        raise
      end
    end
    @binds = []
  end

  def insert_data
    insert_aspects
    insert_companies
    insert_company_aliases
    insert_games
    insert_aliases
    insert_game_aspects
    insert_history
    insert_links
    insert_binds
    insert_suggest
    insert_tag_aspects
    insert_visited
  end

  def insert_aliases
    @pagoda.select('alias') do |aka|
      bind aka[:id],
           aka[:name],
           (aka[:hide] == 'Y') ? 1 : 0
      on_error aka
      execute <<INSERT_ALIAS
insert into alias (id, name, hide)
values (?, ?, ?)
INSERT_ALIAS
    end
    check_errors 'Inserted game aliases'
  end

  def insert_aspects
    @pagoda.select('aspect') do |aspect|
      bind aspect[:name],
           aspect[:index],
           aspect[:type],
           (aspect[:derive] == 'Y') ? 1 : 0
      on_error aspect
      execute <<INSERT_ASPECT
insert into aspect (name, 'index', type, derive)
values (?, ?, ?, ?)
INSERT_ASPECT
    end
    check_errors 'Inserted aspects'
  end

  def insert_binds
    @pagoda.select('bind') do |bound|
      bind bound[:url],
           bound[:id]
      on_error bound
      execute <<INSERT_BIND
insert into bind (url, id)
values (?, ?)
INSERT_BIND
    end
    check_errors 'Inserted binds'
  end

  def insert_companies
    @pagoda.select('company') do |company|
      bind company[:name]
      on_error company
      execute <<INSERT_COMPANY
insert into company (name)
values (?)
INSERT_COMPANY
    end
    check_errors 'Inserted companies'
  end

  def insert_company_aliases
    @pagoda.select('company_alias') do |aka|
      bind aka[:name], aka[:alias]
      on_error aka
      execute <<INSERT_COMPANY_ALIAS
insert into company_alias (name, 'alias')
values (?,?)
INSERT_COMPANY_ALIAS
    end
    check_errors 'Inserted company aliases'
  end

  def insert_games
    prepare <<INSERT_GAME
insert into game (id, name, is_group, group_id, game_type, year, developer, publisher)
values (?, ?, ?, ?, ?, ?, ?, ?)
INSERT_GAME

    @pagoda.select('game') do |game|
      bind game[:id],
           game[:name],
           (game[:is_group] == 'Y') ? 1 : 0,
           game[:group_id],
           game[:game_type],
           game[:year],
           game[:developer],
           game[:publisher]
      on_error game
      execute
    end
    check_errors 'Inserted games'
  end

  def insert_game_aspects
    prepare <<INSERT_GAME_ASPECT
insert into game_aspect (id, aspect, flag)
values (?, ?, ?)
INSERT_GAME_ASPECT

    @pagoda.select('game_aspect') do |game_aspect|
      bind game_aspect[:id],
           game_aspect[:aspect],
           (game_aspect[:flag] == 'Y') ? 1 : 0
      on_error game_aspect
      execute
    end
    check_errors 'Inserted game aspects'
  end

  def insert_history
    @pagoda.select('history') do |history|
      bind history[:site],
           history[:type],
           history[:method],
           history[:state],
           history[:timestamp],
           history[:elapsed]
      on_error history
      execute <<INSERT_HISTORY
insert into history (site, type, method, state, timestamp, elapsed)
values (?, ?, ?, ?, ?, ?)
INSERT_HISTORY
    end
    check_errors 'Inserted history'
  end

  def insert_links
    prepare <<INSERT_LINK
insert into link (site, type, title, url, timestamp, valid, comment, reject, year, static, digest)
values (?, ?, ?, ?, ?, ?, ?, ?, ? ,?, ?)
INSERT_LINK

    @pagoda.select('link') do |link|
      bind link[:site],
           link[:type],
           link[:title] || link[:orig_title] || '???',
           link[:url],
           link[:timestamp],
           link[:valid] ? 1 : 0,
           link[:comment],
           link[:reject] ? 1 : 0,
           link[:year],
           link[:static] ? 1 : 0,
           @pagoda.get_digest(link).to_json
      on_error link
      execute
    end
    check_errors 'Inserted links'
  end

  def insert_suggest
    prepare <<INSERT_SUGGEST
insert into suggest (site, type, title, url)
values (?, ?, ?, ?)
INSERT_SUGGEST

    @pagoda.select('suggest') do |suggest|
      bind suggest[:site],
           suggest[:type],
           suggest[:title] || '???',
           suggest[:url]
      on_error suggest
      execute
    end
    check_errors 'Inserted suggests'
  end

  def insert_tag_aspects
    @pagoda.select('tag_aspects') do |tag_aspect|
      bind tag_aspect[:tag],
           (tag_aspect[:aspect] || '')
      on_error tag_aspect
      execute <<INSERT_TAG_ASPECT
insert into tag_aspects (tag, aspect)
values (?, ?)
INSERT_TAG_ASPECT
    end
    check_errors 'Inserted tag aspects'
  end

  def insert_visited
    @pagoda.select('visited') do |visited|
      bind visited[:key],
           visited[:timestamp]
      on_error visited
      execute <<INSERT_VISITED
insert into visited (key, timestamp)
values (?, ?)
INSERT_VISITED
    end
    check_errors 'Inserted visited'
  end

  def on_error(thing)
    @on_error = thing
  end

  def prepare( statement)
    @prepared = @sqlite3.prepare statement
  end
end

g = GenerateSqliteDatabase.new( ARGV[0], ARGV[1])
File.delete('/tmp/pagoda.sqlite') if File.exist?('/tmp/pagoda.sqlite')
g.create_database(ARGV[2])
#g.create_tables
g.insert_data
g.close