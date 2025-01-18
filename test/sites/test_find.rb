# frozen_string_literal: true
require_relative '../test_base'
require_relative '../../ruby/spider'

class TestFind < TestBase
  include Common

  class TestSpider < Spider
    include Common
    attr_reader :adds, :suggests, :limit, :cache

    def initialize(pagoda, cache, site, type, limit, yday)
      super(pagoda,cache)
      @site  = site
      @type  = type
      @limit = limit
      @yday  = yday
    end

    def browser_get(url)
      if @limit == 0
        '<html><body></body></html>'
      else
        @limit -= 1
        super
      end
    end

    def curl(url)
      if @limit == 0
        nil
      else
        @limit -= 1
        super
      end
    end

    def http_get(url,delay=10,headers={})
      if @limit == 0
        nil
      else
        @limit -= 1
        super
      end
    end

    def http_post( url, delay = 10, headers = {}, body = nil)
      if @limit == 0
        nil
      else
        @limit -= 1
        super
      end
    end

    def yday
      @yday
    end
  end

  def test_adventure_game_hotspot_database
    scan( 'Adventure Game Hotspot', 'Database', :find_database, 2)
    assert_link_count 20
    assert_links_match %r{^https://adventuregamehotspot.com/game/\d+/}
  end

  def test_adventure_game_hotspot_reviews
    scan( 'Adventure Game Hotspot', 'Review',:find_reviews, 2)
    assert_link_count 20
    assert_links_match %r{^https://adventuregamehotspot.com/review/\d+/}
  end

  def test_adventure_gamers_database
    scan( 'Adventure Gamers', 'Database', :find_database, 3)
    assert_link_count 40
    assert_links_match %r{^https://adventuregamers.com/games/view/\d+$}
  end

  def test_adventure_gamers_reviews
    scan( 'Adventure Gamers', 'Review', :find_reviews, 1)
    assert_link_count 15
    assert_links_match %r{^https://adventuregamers.com/articles/view/}
  end

  def test_big_fish_games
    scan( 'Big Fish Games', 'Store', :find_adventures, 2)
    assert_link_count 75
    assert_links_match %r{^https://www.bigfishgames.com/us/en/games/\d+/}
  end

  def test_game_boomers_reviews
    scan( 'GameBoomers', 'Review', :find_reviews, 1)
    assert_link_count 850
    assert_links_match %r{^http(s|)://(www.|)gameboomers.com/reviews/}
  end

  def test_game_boomers_walkthroughs
    scan( 'GameBoomers', 'Walkthrough', :find_walkthroughs, 2, 3)
    assert_link_count 100
    assert_links_match %r{^http(s|)://(www.|)gameboomers.com/(wtcheats|Walkthroughs)/}
  end

  def test_gog
    scan( 'GOG', 'Store',:find, 2)
    assert_links_match %r{^https://www.gog.com/game/}
    assert_link_count 60
  end

  def test_hotu
    scan( 'HOTU', 'Reference', :find, 2)
    assert_link_count 60
    assert_links_match %r{^https://www.homeoftheunderdogs.net/game.php\?id=\d+$}
  end

  def test_igdb
    scan( 'IGDB', 'Reference',:find, 2)
    assert_suggest_count 1000
    assert_suggests_match %r{^https://www.igdb.com/games/}
  end

  def test_just_adventure_reviews
    scan( 'Just Adventure', 'Review', :find_reviews, 2, 1)
    assert_link_count 60
    assert_links_match %r{^https://www.justadventure.com/\d\d\d\d/\d+/\d+/}
  end

  def test_just_adventure_walkthroughs
    scan( 'Just Adventure', 'Walkthrough', :find_walkthroughs, 2)
    assert_link_count 54
    assert_links_match %r{^https://www.justadventure.com/\d\d\d\d/\d+/\d+/}
  end

  def test_moby_games
    scan( 'MobyGames', 'Reference', :find, 1)
    assert_suggest_count 100
    assert_suggests_match %r{^https://www.mobygames.com/game/\d+/}
  end

  def test_mystery_manor_reviews
    scan( 'Mystery Manor', 'Review', :find_reviews, 1)
    assert_link_count 60
    assert_links_match %r{^https://mysterymanor.net/review}
  end

  def test_mystery_manor_walkthroughs
    scan( 'Mystery Manor', 'Walkthrough', :find_walkthroughs, 1)
    assert_link_count 50
    assert_links_match %r{^https://mysterymanor.net/walkthroughs/}
  end

  def test_nice_game_hints_walkthroughs
    scan( 'Nice Game Hints', 'Walkthrough', :find, 1)
    assert_link_count 100
    assert_links_match %r{^https://www.nicegamehints.com/guide/}
  end

  def test_rawg
    scan( 'rawg.io', 'Reference', :find, 2)
    assert_suggest_count 80
    assert_suggests_match %r{^https://rawg\.io/games/}
  end

  def test_steam
    scan( 'Steam', 'Store', :incremental, 1)
    assert_suggest_count 100
    assert_suggests_match %r{^https://store\.steampowered\.com/app/\d+$}
  end

  def test_turn_based_lovers
    scan( 'Turn Based Lovers', 'Review', :findReviews, 2)
    assert_link_count 15
    assert_links_match %r{^https://turnbasedlovers.com/review/}
  end

  def assert_link_count(min)
    assert min <= @pagoda.count('link')
  end

  def assert_links_match(pattern)
    @pagoda.select('link') do |link|
      p link unless pattern =~ link[:url]
      assert pattern =~ link[:url]
    end
  end

  def assert_suggest_count(min)
    assert min <= @pagoda.count('suggest')
  end

  def assert_suggests_match(pattern)
    @pagoda.select('suggest') do |link|
      p link unless pattern =~ link[:url]
      assert pattern =~ link[:url]
    end
  end

  def assert_has_link(pattern)
    found = false
    @pagoda.select('link') do |link|
      if pattern.is_a?(Regexp)
        found = true if pattern =~ link[:url]
      else
        found = true if link[:url].include?(pattern)
      end
    end
    assert found
  end

  def assert_no_such_link(pattern)
    @pagoda.select('link') do |link|
      if pattern.is_a?(Regexp)
        assert(! (pattern =~ link[:url]))
      else
        assert(! link[:url].include?(pattern))
      end
    end
  end

  def scan(site,type,method,limit,yday=0)
    scanner = TestSpider.new(@pagoda, @cache, site, type, limit, yday)
    @pagoda.get_site_handler(site).send(method,scanner,yday)
    assert_equal 0, scanner.limit
  end
end

