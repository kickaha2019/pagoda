require_relative 'default_site'

class Rawg < DefaultSite
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
