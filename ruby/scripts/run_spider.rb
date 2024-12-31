require_relative '../spider'

spider = Spider.new( Pagoda.release( ARGV[0], ARGV[1]), ARGV[1])
spider.browser_driver
spider.send( ARGV[2].to_sym, ARGV[3], ARGV[4])
spider.report