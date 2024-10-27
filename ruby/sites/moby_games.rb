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

	def filter( pagoda, link, page, rec)
		if m = /^(.*)- MobyGames/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_aspects(pagoda, url, page)
		Nodes.parse( page).css('div.info-genres dl.metadata a') do |a|
			tag_to_aspects(pagoda, a.text).each do |aspect|
				yield aspect
			end
			# if mapped = ASPECT_MAP[a.text]
			# 	mapped = [mapped] unless mapped.is_a? Array
			# 	mapped.each {|m| yield m}
			# else
			# 	yield "MobyGames unhandled: #{a.text}"
			# end
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
end
