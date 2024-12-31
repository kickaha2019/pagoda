# frozen_string_literal: true
require_relative '../test_base'
require_relative '../../ruby/spider'

class TestFind < TestBase
  include Common

  class TestSpider < Spider
    include Common
    attr_reader :adds, :suggests, :limit, :cache

    def initialize(pagoda, cache, site, type, limit)
      super(pagoda,cache)
      @site     = site
      @type     = type
      @limit    = limit
    end

    def browser_get(url)
      if @limit == 0
        '<html><body></body></html>'
      else
        @limit -= 1
        super
      end
    end

    def html_anchors(url, delay = 10)
      if @limit == 0
        0
      else
        @limit -= 1
        super
      end
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
    scan( 'Adventure Gamers', 'Database', :find_database, 2)
    assert_link_count 40
    assert_links_match %r{^https://adventuregamers.com/games/view/\d+$}
  end

  def test_adventure_gamers_reviews
    scan( 'Adventure Gamers', 'Review', :find_reviews, 3)
    assert_link_count 25
    assert_links_match %r{^https://adventuregamers.com/articles/view/}
  end

  def test_big_fish_games
    scan( 'Big Fish Games', 'Store', :full, 2)
    assert_link_count 75
    assert_links_match %r{^https://www.bigfishgames.com/us/en/games/\d+/}
  end

  def test_game_boomers_reviews
    scan( 'GameBoomers', 'Review', :findReviews, 1)
    assert_link_count 850
    assert_links_match %r{^http(s|)://(www.|)gameboomers.com/reviews/}
  end

  def test_game_boomers_walkthroughs
    scan( 'GameBoomers', 'Walkthrough', :findWalkthroughs, 3)
    assert_link_count 100
    assert_links_match %r{^http(s|)://(www.|)gameboomers.com/(wtcheats|Walkthroughs)/}
  end

  def test_gog
    @pagoda.add_link('GOG','Store','Test lost 1',
                     'https://www.gog.com/game/test_lost1')
    @pagoda.add_link('GOG','Store','Test lost 2',
                     'https://www.gog.com/game/test_lost2')
    @pagoda.create_game( {:name=>'Test game 2',:id => 100})
    @pagoda.link('https://www.gog.com/game/test_lost2').bind(100)
    scan( 'GOG', 'Store',:find, 2)
    assert_links_match %r{^https://www.gog.com/game/}
    assert_no_such_link 'test_lost1'
    assert_has_link 'test_lost2'
    found = JSON.parse(IO.read(@cache + '/gog.json'))
    assert found.size > 60
    assert_link_count 60
  end

  # def test_hotu
  #   scan( 'HOTU', 'Reference', :find, 2)
  #   assert_link_count 60
  #   assert_links_match %r{^https://www.homeoftheunderdogs.net/game.php?id=\d+$}
  # end

  def assert_link_count(min)
    assert min <= @pagoda.count('link')
  end

  def assert_links_match(pattern)
    @pagoda.select('link') do |link|
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

  def scan(site,type,method,limit)
    scanner = TestSpider.new(@pagoda, @cache, site, type, limit)
    @pagoda.get_site_handler(site).send(method,scanner)
    scanner.add_suggested(1000)
    assert_equal 0, scanner.limit
  end
end

