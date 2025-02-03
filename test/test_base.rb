# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../ruby/common'
require_relative '../ruby/pagoda'
require_relative '../ruby/spider'

class TestBase < Minitest::Test
  def setup
    super

    @metadata, @cache = '/Users/peter/Pagoda/database', '/tmp/Pagoda_cache'
    mkdir @cache
    mkdir @cache + '/verified'
    (0..9).each do |i|
      mkdir @cache + '/verified/' + i.to_s
    end

    @pagoda = Pagoda.testing(@metadata,@cache)
    @spider = Spider.new(@pagoda, @cache)
  end

  def mkdir(path)
    if Dir.exist? path
      Dir.entries(path).each do |f|
        path1 = path + '/' + f
        unless File.directory? path1
          File.unlink path1
        end
      end
    else
      Dir.mkdir path
    end
  end

  def insert_aspect(aspect,index,type=nil,derive=false)
    @pagoda.insert('aspect',{name:aspect,index:index,type:type,derive:(derive ? 'N' : 'Y')})
  end

  def insert_tag_aspect(tag, aspect)
    @pagoda.insert('tag_aspects',{tag:tag,aspect:aspect})
  end

  def insert_history(site,type,method,timestamp,state)
    @pagoda.insert('history',{site:site,type:type,method:method,timestamp:timestamp,state:state,elapsed:1})
  end
end