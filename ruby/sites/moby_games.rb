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

	def find(scanner)
		now_year = Time.now.year
		run_year = scanner.yday % (now_year - 1979) + 1980

		scanner.refresh(run_year) do
			find_genre(scanner, run_year, 'adventure')
			#find_genre(scanner, run_year, 'puzzle')
			#find_genre(scanner, run_year, 'role-playing-rpg')
			#find_genre(scanner, run_year, 'educational')
		end
	end

	def find_genre(scanner, run_year, genre)
		page  = 1
		url   = find_url(run_year, genre, page)
		group = genre + ':' + run_year.to_s

		while url
			old_url, url = url, nil

			raw = scanner.http_get(old_url)
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
						p [game['title'], game['internal_url']]
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
