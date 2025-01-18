require_relative '../spider'

spider = Spider.new( Pagoda.release( ARGV[0], ARGV[1]), ARGV[1])
spider.browser_driver
spider.run( ARGV[2])
spider.report