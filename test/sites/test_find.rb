# frozen_string_literal: true
require_relative '../test_base'

class TestFind < TestBase
  include Common

  class TestSpider
    include Common
    attr_reader :adds, :suggests, :limit, :cache

    def initialize(pagoda, cache, site, type, limit)
      @pagoda   = pagoda
      @cache    = cache
      @site     = site
      @type     = type
      @limit    = limit
      @adds     = {}
      @suggests = {}
    end

    def add_link(label,url)
      return 0 if @adds[url]
      @adds[url]     = label
      @suggests[url] = label
      1
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

    def purge_lost_urls
      @pagoda.purge_lost_urls(@site, @type, @suggests)
    end
  end

  def test_adventure_game_hotspot_database
    adds, _, limit = scan( 'Adventure Game Hotspot', 'Database', :find_database, 2)
    assert_equal 0, limit
    assert adds.size > 20
    assert %r{^https://adventuregamehotspot.com/game/\d+/} =~ adds.keys[0]
  end

  def test_adventure_game_hotspot_reviews
    adds, _, limit = scan( 'Adventure Game Hotspot', 'Review',:find_reviews, 2)
    assert_equal 0, limit
    assert adds.size > 20
    assert %r{^https://adventuregamehotspot.com/review/\d+/} =~ adds.keys[0]
  end

  def test_adventure_gamers_database
    adds, _, limit = scan( 'Adventure Gamers', 'Database', :find_database, 2)
    assert_equal 0, limit
    assert adds.size > 40
    assert %r{^https://adventuregamers.com/games/view/\d+$} =~ adds.keys[0]
  end

  def test_adventure_gamers_reviews
    adds, _, limit = scan( 'Adventure Gamers', 'Review', :find_reviews, 2)
    assert_equal 0, limit
    assert adds.size > 25
    assert %r{^https://adventuregamers.com/articles/view/} =~ adds.keys[0]
  end

  def test_gog
    @pagoda.insert('link',{:url => 'https://www.gog.com/en/game/test_lost1',
                           :site => 'GOG',
                           :type => 'Store'})
    @pagoda.insert('link',{:url => 'https://www.gog.com/game/test_lost2',
                           :site => 'GOG',
                           :type => 'Store'})
    @pagoda.insert('bind',{:url => 'https://www.gog.com/game/test_lost2',:id=>100})
    adds, _, limit = scan( 'GOG', 'Store',:find, 2)
    assert_equal 0, limit
    found = JSON.parse(IO.read(@cache + '/gog.json'))
    assert_equal adds.size, found.size
    assert adds.size > 60
    assert %r{^https://www.gog.com/game/} =~ adds.keys[0]
    assert_equal 0, @pagoda.get('link',:url,'https://www.gog.com/game/test_lost1').size
    assert_equal 1, @pagoda.get('link',:url,'https://www.gog.com/game/test_lost2').size
  end

  def scan(site,type,method,limit)
    scanner = TestSpider.new(@pagoda, @cache, site, type, limit)
    added = @pagoda.get_site_handler(site).send(method,scanner)
    assert_equal added, scanner.adds.size
    return scanner.adds,scanner.suggests,scanner.limit
  end
end

