# frozen_string_literal: true

require_relative '../test_base'

class SpiderTest < TestBase
  def test_none_run
    @spider.run('test')
    site = @pagoda.get_site_handler('Test')
    assert site.ran?('find1')
    assert(! site.ran?('find2'))
    assert site.ran?('find3')
    t,s = get_history('Test','Test','find1')
    assert((Time.now.to_i - t) < 60)
    assert_nil s
    assert_nil get_history('Test','Test','find2')
  end

  def test_some_run
    now = Time.now.to_i
    insert_history('Test','Test','find1',now,'ran')
    insert_history('Test','Test','find3',now,'ran')
    @spider.run('test')
    site = @pagoda.get_site_handler('Test')
    assert(! site.ran?('find1'))
    assert  site.ran?('find2')
    assert(! site.ran?('find3'))
  end

  def test_twice_run
    @spider.run('test')
    @spider.run('test')
    site = @pagoda.get_site_handler('Test')
    assert site.ran?('find2')
  end

  def get_history(site,type,method)
    found = nil
    @pagoda.select('history') do |rec|
      if (rec[:site] == site) && (rec[:type] == type) && (rec[:method] == method)
        assert_nil found
        found = [rec[:timestamp], rec[:state]]
      end
    end
    found
  end
end
