require_relative '../spider'

spider = Spider.new( Pagoda.release( ARGV[0]))
spider.browser_driver
spider.run( ARGV[2])
spider.report