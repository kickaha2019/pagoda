require_relative 'default_site'

class MobyGames < DefaultSite
	ASPECT_MAP = {
		'1st-person'         => '1st person',
		'2D scrolling'       => [],
		'3rd-person (Other)' => '3rd person',
		'Action'             => 'Action',
		'Adventure'          => 'Adventure',
		'Comedy'             => 'Comedy',
		'Platform'           => 'Action',
		'Puzzle elements'    => [],
		'Side view'          => '3rd person'
	}.freeze

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
		Nodes.parse( page).css('div.info-genres dl.metadata a') do |a|
			if mapped = ASPECT_MAP[a.text]
				mapped = [mapped] unless mapped.is_a? Array
				mapped.each {|m| yield m}
			else
				yield "MobyGames unhandled: #{a.text}"
			end
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
