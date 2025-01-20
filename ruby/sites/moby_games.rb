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

	def find_scan(scanner,endpoint,offset,clause='')
		url = <<"URL"
https://api.mobygames.com/v1
#{endpoint}?format=brief&offset=#{offset}&
#{clause}
api_key=#{scanner.settings['MobyGames']}
URL
		url = url.gsub( /\s/, '')
		raw = scanner.http_get(url)
		return 0 if raw.nil?
		json = JSON.parse(raw)

		json['games'].each_index do |i|
			game = json['games'][i]
			yield offset+i, game['title'], game['moby_url']
			#scanner.suggest_link('Recent',game['title'],game['moby_url'])
		end
		json['games'].size
	end
	
	# def find(scanner, _)
	# 	offset, check_first_known, known = 0, false, {}
	# 	scanner.already_suggested do |record|
	# 		if m = /^offset:(\d+)$/.match(record[:group])
	# 			offset            = m[1].to_i
	# 			check_first_known = true
	# 		end
	# 		known[record[:url]] = true
	# 	end
	#
	# 	offset -= 4 if offset > 4
	# 	find_scan( scanner,'/games', offset) do |offset1, label, url|
	# 		if check_first_known
	# 			check_first_known = false
	# 			unless known[url]
	# 				raise "Games order corrupted"
	# 			end
	# 		end
	# 		scanner.suggest_link("offset:#{offset1}", label, url)
	# 	end
	# end

	def find_genre(scanner, genre, state)
		offset, check_first_known, known = 0, false, {}
		if /^\d+$/ =~ state
			offset            = state.to_i
			check_first_known = true
		end

		scanner.already_suggested do |record|
			known[record[:url]] = true
		end

		offset -= 4 if offset > 4
		find_scan( scanner,'/games', offset, "genre=#{genre}&") do |offset1, label, url|
			if check_first_known
				check_first_known = false
				unless known[url]
					raise "Games order corrupted"
				end
			end
			scanner.suggest_link("offset:#{offset1}", label, url)
			offset = offset1
		end

		offset
	end

# 	def find_url(year, genre, page)
# 		url = <<"HTML"
# https://www.mobygames.com/game/from:#{year}/genre:#{genre}/until:#{year}/sort:added/page:#{page}/
# HTML
# 		url.strip
# 	end

	def find_adventures(scanner, state)
		find_genre(scanner,2,state)
	end

	def find_puzzles(scanner, state)
		find_genre(scanner,118,state)
	end

	def find_jrpgs(scanner, state)
		find_genre(scanner,147,state)
	end

	def find_rpgs(scanner, state)
		find_genre(scanner,50,state)
	end

	def find_visual_novels(scanner, state)
		find_genre(scanner,111,state)
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
