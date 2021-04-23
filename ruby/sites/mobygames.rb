class MobyGames
	def find( scanner)
		path = scanner.cache + "/mobygames.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			offset, urls, old_count = 0, {}, -1

			while old_count < urls.size
				old_count = urls.size

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

				offset += 25
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.suggest_link( name, url)
		end
	end
end
