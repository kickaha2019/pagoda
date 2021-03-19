class MobyGames
	def complete?
		true
	end

	def find( scanner, page, lifetime, url2link)
		path = scanner.cache + "/mobygames/#{page}.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			offset, urls = 25 * page, {}

			raw = scanner.http_get "https://www.mobygames.com/browse/games/adventure/offset,#{offset}/so,0a/list-games/"

			raw.split( 'href="').each do |line|
				if m = /^(https:\/\/www.mobygames.com\/game\/[^"]*)">([^<]*)</.match( line)
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
		'MobyGames'
	end

	def type
		'Reference'
	end
end
