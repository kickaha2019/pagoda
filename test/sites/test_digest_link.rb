# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../../ruby/common'
require_relative '../../ruby/pagoda'

class TestDigestLink < Minitest::Test
  include Common

  def test_adventure_classic_gaming
    info = fire('Adventure Classic Gaming',
                'http://www.adventureclassicgaming.com/index.php/site/reviews/465/')
    assert_equal 'Alone in the Dark', info['title']
    assert_equal 2009, info['link_year']
  end

  def test_big_fish_games
    info = fire('Big Fish Games','https://www.bigfishgames.com/us/en/games/2866/undiscovered-world-incan-sun/')
    assert_equal 'Undiscovered World: The Incan Sun', info['title']
    assert /^Stranded on an uncharted island/ =~ info['description']
  end

  def test_brass_lantern
    info = fire('Brass Lantern',
                'http://brasslantern.org/reviews/graphic/badmojoplotkin.html')
    assert_equal 'Bad Mojo', info['title']
    assert_equal 2004, info['link_year']
  end

  def test_game_boomers
    info = fire('GameBoomers',
                'http://www.gameboomers.com/reviews/Nn/Noonelivesforeverbysinger.htm')
    assert_equal 'No One Lives Forever', info['title']
    assert_equal 2003, info['link_year']
  end

  def test_good_old_games
    info = fire('GOG','https://www.gog.com/game/atom_rpg_trudograd')
    assert_equal 'ATOM RPG: Trudograd', info['title']
    assert_equal 2020, info['year']
    assert /<i>Since Trudograd continues/ =~ info['description']
    assert_equal ['AtomTeam'], info['developers']
    assert_equal ['AtomTeam'], info['publishers']
    assert_equal ["GOG", "Windows", "Mac"], info['platforms']
    assert_equal ["accept", "RPG", "Open world"], info['aspects']
  end

  def test_igdb_data
    info = fire('IGDB','https://www.igdb.com/games/a-fork-in-the-tale')
    assert_equal 'A Fork in the Tale', info['title']
    assert_equal 1997, info['year']
    assert /^Developed as/ =~ info['description']
    assert_equal ['Advance Reality Interactive'], info['developers']
    assert_equal ['Any River Entertainment'], info['publishers']
    assert_equal ['Adventure', 'Fantasy', 'Comedy'], info['aspects']
  end

  def test_igdb_nodata
    fire('IGDB','https://www.igdb.com/games/three-sisters-story')
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
    assert_equal ["Steam", "Windows"], info['platforms']
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

  def test_steam_addon
    info = fire('Steam','https://store.steampowered.com/app/2156236')
    assert info['aspects'].include?('reject')
  end

  def test_steam_agecheck
    info = fire('Steam','https://store.steampowered.com/app/1086940')
    assert_equal ["accept", "RPG", "Fantasy", "Adventure"], info['aspects']
    assert_equal ["Steam", "Windows", "Mac"], info['platforms']
    assert_equal "Baldur's Gate 3", info['title']
    assert_equal 2023, info['year']
    assert /Dungeons & Dragons/ =~ info['description']
    assert_equal ["Larian Studios"], info['developers']
    assert_equal ['Larian Studios'], info['publishers']
  end

  def test_steam_not_english
    info = fire('Steam','https://store.steampowered.com/app/1530760')
    assert info['unreleased']
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

