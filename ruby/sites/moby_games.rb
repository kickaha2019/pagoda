require_relative 'digest_site'

class MobyGames < DigestSite
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

	def get_aspects(pagoda, url, page)
		unless page.is_a?(String)
			super {|aspect| yield aspect}
			return
		end

		Nodes.parse( page).css('div.info-genres dl.metadata a') do |a|
			tag_to_aspects(pagoda, a.text).each do |aspect|
				yield aspect
			end
		end
	end

	def get_game_description( page)
		unless page.is_a?(String)
			return super
		end

		page.split( "<h2>").each do |line|
			return line if /^Description/ =~ line
		end
		''
	end

	def get_game_details( url, page, game)
		unless page.is_a?(String)
			super
			return
		end

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
			m[1].to_i
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

	def tag_to_aspects(pagoda, tag)
		@info = pagoda.get_yaml( 'mobygames.yaml') if @info.nil?
		aspects = @info['tags'][tag]
		if aspects.nil?
			["MobyGames unhandled: #{tag}"]
		elsif aspects.is_a? Array
			aspects
		else
			[aspects]
		end
	end

	def name
		'MobyGames'
	end

	def post_load(pagoda, url, page)
		@info    = pagoda.get_yaml( 'mobygames.yaml') if @info.nil?
		tag_info = @info['tags']
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

			aspects = {'accept' => true}
			nodes.css('div.info-genres dl.metadata a') do |tag|
				action = tag_info[tag.text.strip]
				if action.nil?
					aspects["MobyGames: #{tag.text.strip}"] = true
				elsif action.is_a?(String)
					aspects[action] = true
				else
					action.each {|a| aspects[a] = true}
				end
			end
			digest['aspects'] = aspects.keys
		end
	end
end
