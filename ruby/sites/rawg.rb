require_relative 'default_site'

class Rawg < DefaultSite
	BASE = 'https://rawg.io'

	def initialize
		@info         = nil
	end

	def correlate_url( url)
		if %r{^https://rawg\.io/} =~ url
			return 'rawg.io', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def find(scanner, _)
		page = 1
		scanner.already_suggested do |rec|
			page = rec[:group].to_i if rec[:group].to_i > page
		end

		loops = 50
		url = <<"RAWG"
https://api.rawg.io/api/games?key=#{scanner.settings['rawg.io']}&genres=3,5,7,17,34,40&page=#{page}&page_size=40&ordering=created
RAWG
		url = url.strip

		while (loops > 0) && url
			raw = scanner.http_get(url,10,'Accept' => 'application/json')
			#raw = scanner.curl url
			break if raw.nil?

			data = JSON.parse(raw)
			data['results'].each do |game|
				scanner.suggest_link(page,game['name'], BASE + '/games/' + game['slug'])
			end
			url = data['next']
			loops -= 1
			page += 1
		end
	end

	def reduce_title( title)
		if m = /^(.+)- MobyGames/.match( title)
			title = m[1]
		end
		title.strip
	end

	def get_link_year( page)
		if m = /<title>[^<]*\((\d\d\d\d)\)[^<]*<\/title>/i.match( page)
			m[1].to_i
		else
			nil
		end
	end

	def name
		'rawg.io'
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			nodes.css('h1.game__title') do |title|
				digest['title'] = title.text.strip
			end

			nodes.css('div.game__about-text span:first-child') do |desc|
				digest['description'] = desc.text
			end

			get_fields(nodes,'Release date','') do |date|
				if m = / (\d\d\d\d)$/.match(date.text.strip)
					digest['year'] = m[1].to_i
				end
			end

			digest['tags'] = []
			get_fields(nodes,'Genre',' a') do |genre|
				digest['tags'] << genre.text.strip
			end

			get_fields(nodes,'Tags',' a') do |genre|
				digest['tags'] << genre.text.strip
			end

			digest['developers'] = []
			get_fields(nodes,'Developer',' meta') do |field|
				digest['developers'] << field['content']
			end

			digest['publishers'] = []
			get_fields(nodes,'Publisher',' meta') do |field|
				digest['publishers'] << field['content']
			end
		end
	end

	def get_fields(nodes, type, path)
		nodes.css('div.game__meta-title') do |title|
			[title.text.strip]
		end.parent.css("div:nth-child(2)#{path}") do |field, header|
			if header == type
				yield field
			end
		end
	end
end
