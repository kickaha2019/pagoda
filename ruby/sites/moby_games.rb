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

	def find_scan(scanner,endpoint,offset)
		url = <<"URL"
https://api.mobygames.com/v1
#{endpoint}?format=brief&offset=#{offset}&
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
	
	def find(scanner, _)
		offset, check_first_known, known = 0, false, {}
		scanner.already_suggested do |record|
			if m = /^offset:(\d+)$/.match(record[:group])
				offset            = m[1].to_i
				check_first_known = true
			end
			known[record[:url]] = true
		end

		offset -= 4 if offset > 4
		find_scan( scanner,'/games', offset) do |offset1, label, url|
			if check_first_known
				check_first_known = false
				unless known[url]
					raise "Games order corrupted"
				end
			end
			scanner.suggest_link("offset:#{offset1}", label, url)
		end
	end

	def find_genre(scanner, run_year, genre)
		page  = 1
		url   = find_url(run_year, genre, page)
		group = genre + ':' + run_year.to_s

		while url
			old_url, url = url, nil

			raw = scanner.http_get(old_url)
			return if raw.nil?
			raw.force_encoding( 'UTF-8')
			raw.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			File.open('/tmp/moby.html','w') do |io|
				io.write(raw)
			end

			raw.split("\n").each do |line|
				if m = /^\s*:initial-values='(.*)'\s*$/.match( line)
					data = JSON.parse(m[1])
					suggested = ! scanner.has_suggests?(group)

					data['games'].each do |game|
						suggested |= scanner.suggest_link( group, game['title'], game['internal_url'])
					end

					if suggested && (data['page'] < data['maxPages'])
						page += 1
						url  = find_url(run_year, genre, page)
					end
					break
				end
			end
		end
	end

	def find_url(year, genre, page)
		url = <<"HTML"
https://www.mobygames.com/game/from:#{year}/genre:#{genre}/until:#{year}/sort:added/page:#{page}/
HTML
		url.strip
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
