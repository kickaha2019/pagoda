require 'json'

class Reddit < DefaultSite
	include Common

	def initialize
		@old_urls  = {}
		@page      = 0
		@afters    = {}
		@times     = {}
		@completed = true
	end

	def complete?( scanner)
		return false if @page < 5
		unless @completed
			@old_urls.each_pair do |subreddit, urls|
				scanner.save_snapshot( urls, 'reddit_' + subreddit + '.json')
			end
			@times.each_pair do |subreddit, created|
				puts "... Reddit #{subreddit} #{Time.at( created.to_i).strftime( '%y-%m-%d')}"
			end
			@completed = true
		end
		true
	end

	def find( scanner, page, lifetime, url2link)
		@page = page
		return if complete?( scanner)

		find_reddit( scanner, page, lifetime, url2link, 'iosgaming') do |subreddit, name, link|
			if m = /.*\.apple\.com\/.*\/app\/.*\/([^\/]*)(\?|$)/.match( link)
				url = "https://apps.apple.com/us/app/#{m[1]}"
				url2link[url] = {site:'IOS',
												 type:'Store',
												 title:name,
												 url:url}
				@old_urls[subreddit][url] = name
				scanner.debug_hook( 'reddit:ios', name, link)
			end
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

		json = load_json( scanner, lifetime, subreddit)
		json['data']['children'].each do |child|
			@times[subreddit] = child['data']['created']
			find_urls( child['data']['selftext']) do |name, link|
				name.force_encoding( 'UTF-8')
				name.encode!( 'US-ASCII',
											:invalid => :replace, :undef => :replace, :universal_newline => true)
				yield subreddit, name, link
			end
		end

		@afters[subreddit] = json['data']['after']
	end

	def find_urls( text)
		if m = /^(.*)\[([^\]]*)\]\(([\)]*)\)(.*)$/m.match( text)
			find_urls( m[1]) {|n,l| yield n,l}
			yield m[2], m[3]
			find_urls( m[4]) {|n,l| yield n,l}
		else
			text.gsub( /(\s|^)http(s|):\S*(\s|$)/) do |link|
				yield link.strip, link.strip
			end
		end
	end

	def load_json( scanner, lifetime, subreddit)
		path = scanner.cache + "/reddit_#{@afters[subreddit]}.json"

		after = @afters[subreddit] ? "&after=#{@afters[subreddit]}" : ''
		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			body = http_get( "https://www.reddit.com/r/#{subreddit}/new.json?limit=100#{after}",
											 10,
											 'Accept' => 'application/json')
			File.open( path, 'w') {|io| io.print body}
		end

		JSON.parse( IO.read( path))
	end

	def name
		'Reddit'
	end
end
