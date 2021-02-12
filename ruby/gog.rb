class GOG
	def accept( scanner, name, url)
		true
	end

	def find( scanner, lifetime)
		path = scanner.cache + '/gog.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			loop, page, urls = true, 0, {}

			while (page < 200) && loop
				page += 1
				old_size = urls.size
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page}&sort=release_asc"

				raw.split( ' ng-href="').each do |line|
					if m = /^(\/game[^"]*)">[^>]*>([^<]*)</.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls['https://www.gog.com' + m[1]] = text
					end
				end

				loop = (urls.size != old_size)
			end

			raise "Too many GOG pages" if loop
			found = urls.keys.collect {|k| [urls[k], k]}
			File.open( path, 'w') {|io| io.print JSON.generate( {'found' => found})}
		end

		JSON.parse( IO.read( path))['found']
	end

	def title
		'GOG'
	end

	def type
		'Store'
	end
end
