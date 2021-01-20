class MobyGames
	def accept( scanner, name, url)
		true
	end

	def title
		'MobyGames'
	end

	def type
		'Reference'
	end

	def urls( scanner, lifetime)
		path = scanner.cache + '/mobygames.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			loop, offset, urls = true, 0, {}

			while (offset < 30000) && loop
				old_size = urls.size
				raw = scanner.http_get "https://www.mobygames.com/browse/games/adventure/offset,#{offset}/so,0a/list-games/"

				raw.split( 'href="').each do |line|
					if m = /^(https:\/\/www.mobygames.com\/game\/[^"]*)">([^<]*)</.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls[text] = m[1]
					end
				end

				loop = (urls.size != old_size)
				offset += 25
			end

			raise "Too many MobyGames pages" if loop
			File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => urls})}
		end

		JSON.parse( IO.read( path))['urls']
	end
end
