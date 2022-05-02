require_relative 'default_site'

class Steam < DefaultSite
	def complete?( scanner)
		true
	end

	def find( scanner)
		path = scanner.cache + '/steam.json'

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end
		end

		raw = JSON.parse( IO.read( path))['applist']['apps']
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url = "https://store.steampowered.com/app/#{record['appid']}"
			scanner.suggest_link( text, url)
			scanner.debug_hook( 'Steam:urls', text, url)
		end

		scanner.purge_lost_urls( /^https:\/\/store\.steampowered\.com\/app\//)
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*) on Steam$/.match( rec[:title].strip)
			rec[:title] = m[1]
			return true
		end
		return true if /\/agecheck\/app\//  =~ link.url
		return true if /^Site Error$/       =~ rec[:title]
		return true if /^Welcome to Steam$/ =~ rec[:title]
		rec[:valid] = false
		false
	end

	def get_game_description( page)
		page.scan( Regexp.new( /<a href="https:\/\/store.steampowered.com\/tags\/en\/[^<]*<\/a>/m)).join( ' ')
	end

	def get_game_details( url, page, game)
		publisher, developer, release = false, false, false
		page.split("<div").each do |line|
			if />Publisher:<\/div/ =~ line
				#p ['get_game_details1', line]
				publisher = true
			elsif />Developer:<\/div/ =~ line
				#p ['get_game_details2', line]
				developer = true
			elsif />Release Date:<\/div/ =~ line
				#p ['get_game_details3', line]
				release = true
			elsif m = />([^<]+)<\//.match( line)
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

	def name
		'Steam'
	end
end
