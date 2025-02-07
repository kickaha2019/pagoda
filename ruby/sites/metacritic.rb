require_relative '../nodes'
require_relative 'default_site'

class Metacritic < DefaultSite
	def correlate_url( url)
		if %r{^https://www.metacritic.com/} =~ url
			return 'Metacritic', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def find_genre(scanner,genre,state)
		year,page = 1980,1
		if m = /^(\d+) (\d+)$/.match(state)
			year, page = m[1].to_i, m[2].to_i
		end

		loops = 4
		while loops > 0
			found = false

			raw = scanner.http_get( "https://www.metacritic.com/browse/game/all/#{genre}/#{year}/new/?genre=#{genre}&page=#{page}")
			Nodes.parse(raw).css('a') do |anchor|
				if %r{^/game/.+} =~ anchor['href']
					[anchor['href']]
				else
					nil
				end
			end.css('div.c-finderProductCard_title') do |title, href|
				found = true
				scanner.suggest_link(title['data-title'],"https://www.metacritic.com#{href}")
			end

			if found
				page += 1
			else
				year,page = (year+1),1
				if year > Time.now.year
					year = 1980
				end
			end

			loops -= 1
		end

		"#{year} #{page}"
	end

	def find_adventures(scanner,state)
		find_genre(scanner,'adventure',state)
	end

	def find_puzzles(scanner,state)
		find_genre(scanner,'puzzle',state)
	end

	def find_rpgs(scanner,state)
		find_genre(scanner,'rpg',state)
	end

	def name
		'Metacritic'
  end

	def post_load(pagoda, url, page)
		{}.tap do |digest|
			nodes = Nodes.parse(page)

			nodes.css('div.c-productHero_title h1') do |title|
				digest['title'] = title.text
			end

			nodes.css('span.c-productionDetailsGame_description') do |desc|
				digest['description'] = desc.text
			end

			get_info(nodes,'Initial Release Date:') do |date|
				if m = /(\d\d\d\d)$/.match( date )
					digest['year'] = m[1].to_i
				end
			end

			digest['developers']  = get_companies(nodes,'Developer:')
			digest['publishers']  = get_companies(nodes,'Publisher:')
		end
	end

	def get_companies(nodes, type)
		[].tap do |companies|
			get_info(nodes, type) do |name|
				companies << name
			end
		end
	end

	def get_info(nodes, type)
		nodes.css( 'span.u-block') do |span|
			if span.text == type
				[]
			else
				nil
			end
		end.parent( 1).css( '.g-color-gray70') do |span1|
			yield span1.text.strip
		end
	end
end
