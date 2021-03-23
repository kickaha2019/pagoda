class GOG
	def complete?( scanner)
		true
	end

	def find( scanner, page, lifetime, url2link)
		path = scanner.cache + "/gog/#{page}.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			urls = {}
			raw = scanner.browser_get "https://www.gog.com/games?page=#{page+1}&sort=release_asc"

			raw.split( ' ng-href="').each do |line|
				if m = /^(\/game[^"]*)">[^>]*>([^<]*)</.match( line)
					text = m[2]
					text.force_encoding( 'UTF-8')
					text.encode!( 'US-ASCII',
												:invalid => :replace, :undef => :replace, :universal_newline => true)
					urls['https://www.gog.com' + m[1]] = text
				end
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			url2link[url] = {site:title, type:type, title:name, url:url}
		end
	end

	def title
		'GOG'
	end

	def type
		'Store'
	end
end
