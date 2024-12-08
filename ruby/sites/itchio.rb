require_relative 'default_site'

class Itchio < DefaultSite
	def correlate_url( url)
		if %r{^https://[^./]+\.itch\.io/} =~ url
			return 'itch.io', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def name
		'itch.io'
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			if m = /<title[^>]*>([^<]*)<\/title>/im.match( page)
				title = m[1].gsub( /\s/, ' ')
				digest['title'] = reduce_title(title.strip.gsub( '  ', ' '))
			end
			nodes.css('div.formatted_description') do |desc|
				digest['description'] = desc.text
			end
			digest['tags']        = []
			digest['developers']  = []
			digest['publishers']  = []

			nodes.css('div.info_panel_wrapper a') do |anchor|
				if %r{^https://itch\.io/games/(genre|tag)-} =~ anchor['href']
					digest['tags'] << anchor.text
				elsif anchor['href'] == url[0...(anchor['href'].length)]
					digest['developers'] << anchor.text
					digest['publishers'] << anchor.text
				end
			end
		end
	end
end
