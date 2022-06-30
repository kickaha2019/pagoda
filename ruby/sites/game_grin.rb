require_relative 'default_site'

class GameGrin < DefaultSite
	def find( scanner)
		path = scanner.cache + "/game_grin.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			offset, urls, old_count = 0, {}, -1

			while (old_count < urls.size)
				old_count = urls.size

				raw = scanner.http_get "https://www.gamegrin.com/reviews/?start=#{offset}"
				#File.open( '/Users/peter/temp/game_grin.html', 'w') {|io| io.print raw}
				#raw = IO.read( '/Users/peter/temp/game_grin.html')

				raw.split( 'href="').each do |line|
					if m = /^\/reviews\/([^"]*)\/">([^<]*)Review<\/a/.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						text = text.sub( /\?$/, '')
						urls['https://www.gamegrin.com/reviews/' + m[1]] = text
					end
				end

				offset += 15
			end

			if urls.size < 1000
				scanner.error( 'Not enough URLs found for ' + name)
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.suggest_link( name, url)
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'GameGrin'
  end
end
