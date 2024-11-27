# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../../ruby/common'
require_relative '../../ruby/pagoda'

class TestPostLoad < Minitest::Test
  include Common

  def test_big_fish_games
    info = fire('Big Fish Games','https://www.bigfishgames.com/us/en/games/2866/undiscovered-world-incan-sun/')
    assert_equal 'Undiscovered World: The Incan Sun', info['title']
    assert /^Stranded on an uncharted island/ =~ info['description']
  end

  def test_good_old_games
    info = fire('GOG','https://www.gog.com/game/atom_rpg_trudograd')
    assert_equal 'ATOM RPG: Trudograd', info['title']
    assert_equal 2020, info['year']
    assert /<i>Since Trudograd continues/ =~ info['description']
    assert_equal ['AtomTeam'], info['developers']
    assert_equal ['AtomTeam'], info['publishers']
    assert_equal ["Windows", "Mac"], info['platforms']
    assert_equal ["accept", "RPG", "Open world"], info['aspects']
  end

  def test_igdb
    info = fire('IGDB','https://www.igdb.com/games/a-fork-in-the-tale')
    assert_equal 'A Fork in the Tale', info['title']
    assert_equal 1997, info['year']
    assert /^Developed as/ =~ info['description']
    assert_equal ['Advance Reality Interactive'], info['developers']
    assert_equal ['Any River Entertainment'], info['publishers']
    assert_equal ['Adventure', 'Fantasy', 'Comedy'], info['aspects']
  end

  def test_moby_games
    info = fire('MobyGames','https://www.mobygames.com/game/20148/agon-episode-1-london-scene/')
    assert_equal 'AGON: Episode 1 - London Scene (2003)', info['title']
    assert_equal 2003, info['year']
    assert /Professor Samuel Hunt/ =~ info['description']
    assert_equal ['Private Moon Studios'], info['developers']
    assert_equal ['Private Moon Studios'], info['publishers']
    assert_equal ["Adventure", "1st person"], info['aspects']
  end

  def test_steam_released
    info = fire('Steam','https://store.steampowered.com/app/1687950')
    assert_equal ["Windows"], info['platforms']
    assert_equal 'Persona 5 Royal', info['title']
    assert_equal 2022, info['year']
    assert /Phantom Thieves of Hearts/ =~ info['description']
    assert_equal ["ATLUS"], info['developers']
    assert_equal ['SEGA'], info['publishers']
    assert_equal ["accept", "RPG", "JRPG", "Visual novel", "Adventure", "Investigation"], info['aspects']
    assert_nil info['unreleased']
  end

  def test_steam_unreleased
    info = fire('Steam','https://store.steampowered.com/app/2160070')
    assert info['unreleased']
  end

  def test_steam_agecheck
    info = fire('Steam','https://store.steampowered.com/app/1086940')
    assert_equal ["accept"], info['aspects']
  end

  def setup
    super

    metadata, cache = '/Users/peter/Pagoda/database', '/tmp/Pagoda_cache'
    mkdir cache
    mkdir cache + '/verified'
    (0..9).each do |i|
      mkdir cache + '/verified/' + i.to_s
    end

    @pagoda = Pagoda.testing(metadata,cache)
  end

  def fire(site,url)
    status, result = @pagoda.get_site_handler(site).digest_link(@pagoda, url)
    assert status, result
    result
  end

  def mkdir(path)
    unless Dir.exist? path
      Dir.mkdir path
    end
  end
end

