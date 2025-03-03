# frozen_string_literal: true
require_relative '../test_base'

class TestDigestLink < TestBase
  include Common

  def test_adventure_classic_gaming
    info = fire('Adventure Classic Gaming',
                'http://www.adventureclassicgaming.com/index.php/site/reviews/465/')
    assert_equal 'Alone in the Dark', info['title']
    assert_equal 2009, info['link_year']
  end

  def test_adventure_game_hotspot_database
    info = fire('Adventure Game Hotspot',
                'https://adventuregamehotspot.com/game/46/brok-the-investigator')
    assert_equal 'BROK the InvestiGator', info['title']
    assert_equal 2022, info['year']
    assert_equal ['COWCAT'], info['developers']
    assert_equal ['COWCAT'], info['publishers']
    assert info['tags'].include?('Stylized')
  end

  def test_adventure_gamers_database_released
    info = fire('Adventure Gamers',
                'https://adventuregamers.com/games/view/21418')
    assert_equal '1954: Alcatraz (2014)', info['title']
    assert info['tags'].include?('Stylized art')
    assert_equal 2014, info['year']
  end

  def test_adventure_gamers_database_unreleased
    info = fire('Adventure Gamers',
                'https://adventuregamers.com/games/view/16888')
    assert info['unreleased']
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
    #assert_equal 'No One Lives Forever', info['title']
    assert_equal 2003, info['link_year']
  end

  def test_good_old_games1
    info = fire('GOG','https://www.gog.com/game/atom_rpg_trudograd')
    assert_equal 'ATOM RPG: Trudograd', info['title']
    assert_equal 2020, info['year']
    assert /<i>Since Trudograd continues/ =~ info['description']
    assert_equal ['AtomTeam'], info['developers']
    assert_equal ['AtomTeam'], info['publishers']
    assert_equal ["GOG", "Windows", "Mac"], info['platforms']
    assert info['tags'].include?('Post-apocalyptic')
  end

  def test_good_old_games_addon
    info = fire('GOG','https://www.gog.com/en/game/chained_echoes_ashes_of_elrant')
    assert info['tags'].include?('reject')
  end

  def test_hotu
    info = fire('HOTU','https://www.homeoftheunderdogs.net/game.php?id=114')
    assert_equal 'Beneath a Steel Sky', info['title']
    assert /Lure of The Temptress/ =~ info['description']
    assert_equal 1994, info['year']
    assert_equal ['Revolution'], info['developers']
    assert_equal ['Freeware'], info['publishers']
    assert_equal ["Cyberpunk", "Cartoon"], info['tags']
  end

  def test_itchio
    info = fire('itch.io','https://hanabarger-digital.itch.io/tmos')
    assert_equal 'The Manse on Soracca by MoonMuse', info['title']
    assert /Herbert Castaigne/ =~ info['description']
    assert info['tags'].include?('Lovecraftian Horror')
    assert_equal ['MoonMuse'], info['developers']
    assert_equal ['MoonMuse'], info['publishers']
  end

  def test_igdb_data
    info = fire('IGDB','https://www.igdb.com/games/a-fork-in-the-tale')
    assert_equal 'A Fork in the Tale', info['title']
    assert_equal 1997, info['year']
    assert /^Developed as/ =~ info['description']
    assert_equal ['Advance Reality Interactive'], info['developers']
    assert_equal ['Any River Entertainment'], info['publishers']
    assert info['tags'].include?('Comedy')
  end

  def test_igdb_nodata
    fire('IGDB','https://www.igdb.com/games/three-sisters-story')
  end

  def test_just_adventure
    info = fire('Just Adventure',
                'https://www.justadventure.com/2012/08/25/agatha-christie-evil-under-the-sun-review-2-of-22/')
    assert_equal 'Agatha Christie: Evil Under the Sun', info['title']
    assert_equal 2012, info['link_year']
  end

  def test_metacritic
    info = fire('Metacritic',
                'https://www.metacritic.com/game/puzzle-quest-2/')
    assert_equal 'Puzzle Quest 2', info['title']
    assert_equal 2010, info['year']
    assert /demon Gorgon/ =~ info['description']
    assert_equal ["Infinite Interactive"], info['developers']
    assert_equal ["D3Publisher"], info['publishers']
  end

  def test_moby_games1
    info = fire('MobyGames','https://www.mobygames.com/game/20148/agon-episode-1-london-scene/')
    #p info
    assert_equal 'AGON: Episode 1 - London Scene (2003)', info['title']
    assert_equal 2003, info['year']
    assert /Professor Samuel Hunt/ =~ info['description']
    assert_equal ['Private Moon Studios'], info['developers']
    assert_equal ['Private Moon Studios'], info['publishers']
    assert info['tags'].include?('Puzzle elements')
  end

  def test_moby_games2
    info = fire('MobyGames','https://www.mobygames.com/game/194984/mystical-riddles-behind-dolls-eyes-collectors-edition/')
    assert_equal 'Mystical Riddles: Behind Doll s Eyes (Collector&#39;s Edition) (2022)', info['title']
  end

  def test_rawg
    info = fire('rawg.io','https://rawg.io/games/memento-mori')
    assert_equal 'Memento Mori', info['title']
    assert_equal 2012, info['year']
    assert info['tags'].include?('Adventure')
    assert info['tags'].include?('First-Person')
    assert info['developers'].include?('Shea Kelly')
    assert info['publishers'].include?('WolfWare Studios')
  end

  def test_steam_released
    info = fire('Steam','https://store.steampowered.com/app/1687950')
    assert_equal ["Steam", "Windows"], info['platforms']
    assert_equal 'Persona 5 Royal', info['title']
    assert_equal 2022, info['year']
    assert /Phantom Thieves of Hearts/ =~ info['description']
    assert_equal ["ATLUS"], info['developers']
    assert_equal ['SEGA'], info['publishers']
    assert info['tags'].include?('Colorful')
    assert_nil info['unreleased']
  end

  def test_steam_unreleased
    info = fire('Steam','https://store.steampowered.com/app/2160070')
    assert info['unreleased']
  end

  def test_steam_addon
    info = fire('Steam','https://store.steampowered.com/app/2156236')
    assert info['unreleased']
  end

  def test_steam_agecheck
    info = fire('Steam','https://store.steampowered.com/app/1086940')
    assert info['tags'].include?('Turn-Based Combat')
    assert_equal ["Steam", "Windows", "Mac"], info['platforms']
    assert_equal "Baldur's Gate 3", info['title']
    assert_equal 2023, info['year']
    assert /Dungeons & Dragons/ =~ info['description']
    assert_equal ["Larian Studios"], info['developers']
    assert_equal ['Larian Studios'], info['publishers']
  end

  def test_steam_porn
    info = fire('Steam','https://store.steampowered.com/app/2154130')
    assert info['unreleased']
  end

  def test_steam_not_english
    info = fire('Steam','https://store.steampowered.com/app/1530760')
    assert info['unreleased']
  end

  def fire(site,url)
    status, delete, result = @pagoda.get_site_handler(site).digest_link(@pagoda, url)
    assert status, result
    assert( delete === false)
    force_ascii result
  end
end

