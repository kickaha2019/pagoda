# frozen_string_literal: true
require_relative '../test_base'

class TestDigestLink < TestBase
  include Common

  class TestSpider
    include Common
    attr_reader :adds, :suggests, :limit

    def initialize(limit)
      @limit    = limit
      @adds     = []
      @suggests = []
    end

    def add_link(label,url)
      @adds << [label,url]
      1
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
    adds, _, limit = scan( 'Adventure Game Hotspot', :find_database, 2)
    assert_equal 0, limit
    assert adds.size > 20
    assert %r{^https://adventuregamehotspot.com/game/\d+/} =~ adds[0][1]
  end

  def scan(site,method,limit)
    scanner = TestSpider.new limit
    @pagoda.get_site_handler(site).send(method,scanner)
    return scanner.adds,scanner.suggests,scanner.limit
  end
end

