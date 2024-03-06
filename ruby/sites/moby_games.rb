require_relative 'default_site'

class MobyGames < DefaultSite
	def correlate_url( url)
		if %r{^https://www\.mobygames\.com/} =~ url
			return 'MobyGames', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*)- MobyGames/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_game_description( page)
		desc, in_desc = [], false
		page.split( "<h2>").each do |line|
			return line if /^Description/ =~ line
		end
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

	def name
		'MobyGames'
	end

	def tag_aspects( pagoda, page)
		if page.include? 'https://www.mobygames.com/genre/sheet/1st-person/'
			yield '1st person'
		end

		if page.include? 'https://www.mobygames.com/genre/sheet/3rd-person/'
			yield '3rd person'
		end

		if page.include? 'https://www.mobygames.com/genre/sheet/side-view/'
			yield '3rd person'
		end
	end
end
