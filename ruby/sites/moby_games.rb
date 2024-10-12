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

	def get_aspects(pagoda, page)
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

	def get_game_description( page)
		desc, in_desc = [], false
		page.split( "<h2>").each do |line|
			return line if /^Description/ =~ line
		end
		page
	end

	def get_game_details( url, page, game)
		publisher, developer = false, false

		if year = get_link_year( page)
			game[:year] = year
		end

		page.split( "\n").each do |line|
			publisher = true if /<dt>Publishers<\/dt>/ =~ line
			developer = true if /<dt>Developers<\/dt>/ =~ line

			if m = />([^<]*)<\/a>/.match( line)
				if publisher
					append_details( game, :publisher, m[1])
				elsif developer
					append_details( game, :developer, m[1])
				end

				publisher, developer = false, false
			end
		end
	end

	def get_link_year( page)
		if m = /<title>[^<]*\((\d\d\d\d)\)[^<]*<\/title>/i.match( page)
			m[1]
		else
			nil
		end
	end

	def append_details( game, key, text)
		if game[key]
			game[key] = game[key] + ', ' + text
		else
			game[key] = text
		end
	end

	def name
		'MobyGames'
	end
end
