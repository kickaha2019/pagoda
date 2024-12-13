# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../ruby/common'
require_relative '../ruby/pagoda'

class TestBase < Minitest::Test
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

  def mkdir(path)
    unless Dir.exist? path
      Dir.mkdir path
    end
  end

  def insert_tag_aspect(tag, aspect)
    @pagoda.insert('tag_aspects',{tag:tag,aspect:aspect})
  end
end