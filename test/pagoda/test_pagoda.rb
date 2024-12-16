# frozen_string_literal: true

require_relative '../test_base'

class PagodaTest < TestBase
  class TestLink
    attr_reader :site, :complaint

    def initialize(site)
      @site      = site
      @complaint = nil
    end

    def complain(msg)
      @complaint = msg
    end
  end

  def test_ignore
    insert_tag_aspect('Adventure','Adventure')
    insert_tag_aspect('Adventure','accept')
    insert_tag_aspect('2D Fighter','reject')
    link = TestLink.new('IGDB')

    digest = {}
    assert ! @pagoda.reject_link?( link, digest)
    digest = {'aspects' => ['accept']}
    assert ! @pagoda.reject_link?(link, digest)
    digest = {'aspects' => ['accept','reject']}
    assert @pagoda.reject_link?(link, digest)
    digest = {'aspects' => []}
    assert @pagoda.reject_link?(link, digest)
    digest = {'tags' => ['Adventure']}
    assert ! @pagoda.reject_link?(link, digest)
    digest = {'tags' => ['Adventure','2D Fighter']}
    assert @pagoda.reject_link?(link, digest)
    digest = {'tags' => []}
    assert @pagoda.reject_link?(link, digest)
  end

  def test_digest_aspects
    insert_tag_aspect('Adventure','Adventure')
    insert_tag_aspect('Adventure','accept')
    link = TestLink.new('IGDB')
    assert_equal [], digest_aspects(link,{})
    assert_equal ["Adventure", "accept", "reject"],
                 digest_aspects(link,{'aspects' => ['accept','Adventure','reject']})
    assert_equal 'Unknown aspect: xxx', digest_aspects_complaint(link,{'aspects' => ['xxx']})
    assert_equal ["Adventure", "accept"],
                 digest_aspects(link,{'tags' => ['Adventure']})
    assert_equal "Unhandled tag for IGDB", digest_aspects_complaint(link,{'tags' => ['xxx']})
  end

  def digest_aspects(link,digest)
    aspects = []
    @pagoda.digest_aspects(link, digest) do |aspect|
      aspects << aspect
    end
    aspects.uniq.sort
  end

  def digest_aspects_complaint(link,digest)
    link.complain(nil)
    @pagoda.digest_aspects(link, digest) {|aspect|}
    link.complaint
  end
end
