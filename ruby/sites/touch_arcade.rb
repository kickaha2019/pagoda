class TouchArcade
	def complete?
		true
	end

	def find( scanner, page, lifetime, url2link)
		path = scanner.cache + "/touch_arcade/#{page}.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			urls = {}

			raw = scanner.http_get "https://toucharcade.com/category/reviews/page/#{page+1}"

			raw.split( "\n").each do |line|
				if m = /<a href=\"([^"]*)\" rel=\"bookmark\">([^<]*)<\/a>/.match( line)
					text = m[2]
					text.force_encoding( 'UTF-8')
					text.encode!( 'US-ASCII',
												:invalid => :replace, :undef => :replace, :universal_newline => true)
					urls[m[1]] = text
				end
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			url2link[url] = {site:title, type:type, title:name, url:url}
		end
	end

	def title
		'TouchArcade'
	end

	def type
		'Review'
	end
end
