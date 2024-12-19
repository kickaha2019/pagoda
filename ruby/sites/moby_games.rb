require_relative 'default_site'

class MobyGames < DefaultSite
	def initialize
		@info         = nil
	end

	def correlate_url( url)
		if %r{^https://www\.mobygames\.com/} =~ url
			return 'MobyGames', 'Reference', url
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
		'MobyGames'
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			if m = /<title[^>]*>([^<]*)<\/title>/im.match( page)
				title = m[1].gsub( /\s/, ' ')
				digest['title'] = reduce_title(title.strip.gsub( '  ', ' '))
			end
			nodes.css('#description-text') do |desc|
				digest['description'] = desc.text
			end
			digest['year']        = get_link_year(page)
			digest['developers']  = []
			digest['publishers']  = []

			publisher, developer = false, false
			page.split( "\n").each do |line|
				publisher = true if /<dt>Publishers<\/dt>/ =~ line
				developer = true if /<dt>Developers<\/dt>/ =~ line

				if m = />([^<]*)<\/a>/.match( line)
					if publisher
						digest['publishers'] << m[1]
					elsif developer
						digest['developers'] << m[1]
					end

					publisher, developer = false, false
				end
			end

			tags = []
			nodes.css('div.info-genres dl.metadata a') do |tag|
				tags << tag.text.strip
			end
			digest['tags'] = tags.uniq
		end
	end
end
