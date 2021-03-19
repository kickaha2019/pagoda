require 'json'

class Reddit
	include Common

	def initialize
		@old_urls = {}
		@page     = 0
	end

	def complete?
		@page >= 400
	end

	def find( scanner, page, lifetime, url2link)
		find_reddit( scanner, page, lifetime, url2link, 'iosgaming')
		return if page > 0
		path = scanner.cache + '/reddit.json'

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			body = http_get( 'https://www.reddit.com/r/iosgaming/new.json',
											 10,
											 'Accept' => 'application/json')
			File.open( '/Users/peter/temp/reddit.json', 'w') {|io| io.print body}
			raise 'Dev'
		end

		raw = JSON.parse( IO.read( path))['applist']['apps']
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url2link[url] = {site:title,
											 type:type,
											 title:text,
											 url:"https://store.steampowered.com/app/#{record['appid']}"}
			scanner.debug_hook( 'Steam:urls', text, urls[-1][1])
		end
	end

	# Top level get kind data
	# data -> modhash dist children after before
	# children[] -> kind, data
	# children data -> selftext, selftext_html
	def find_reddit( scanner, page, lifetime, url2link, subreddit)
		if page == 0
			@old_urls[subreddit] = {}
			if saved = scanner.load_snapshot( 'reddit_' + subreddit + '.json')
				@old_urls[subreddit] = JSON.parse( saved)
				@old_urls[subreddit].each_pair {|k,v| url2link[k] = v}
			end
		end

		old_urls['data']['children'].each do |child|
			puts child['data']['selftext']
		end
		puts old_urls['data']['after']
		raise 'Dev'
	end
end
