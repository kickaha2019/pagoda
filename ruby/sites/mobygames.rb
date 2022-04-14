require_relative 'default_site'

class MobyGames < DefaultSite
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

	def get_game_description( page)
		page
	end

	def get_game_details( url, page, game)
		publisher, developer, release = false, false, false
		page.split("<div").each do |line|
			if />Published\s+by</ =~ line
				#p ['get_game_details1', line]
				publisher = true
			elsif />Developed\s+by</ =~ line
				#p ['get_game_details2', line]
				developer = true
			elsif />Released</ =~ line
				#p ['get_game_details3', line]
				release = true
			elsif m = />([^<]*)<\/a>/.match( line)
				text = m[1].gsub( '&nbsp;', ' ')
				#p ['get_game_details4', text]
				if publisher
					game[:publisher] = text
				elsif developer
					game[:developer] = text
				elsif release
					if m2 = /(\d\d\d\d)$/m.match( text)
						game[:year] = m2[1]
					end
				end
				publisher, developer, release = false, false, false
			end
		end
	end
end
