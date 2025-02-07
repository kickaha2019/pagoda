require_relative 'default_site'

class Hotu < DefaultSite
	def initialize
		@info         = nil
	end

	def coerce_url( url)
		if m = /^http:(.*)$/.match( url)
			return 'https:' + m[1]
		end

		if m = /^(www.*)$/.match( url)
			return 'https://' + m[1]
		end

		url
	end

	def find_adventure(scanner, _)
		find_genre(scanner, 3)
	end

	def find_puzzle(scanner, _)
		find_genre(scanner, 6)
	end

	def find_rpg(scanner, _)
		find_genre(scanner, 7)
	end

	def find_genre( scanner, genre)
		base = "https://www.homeoftheunderdogs.net/genre.php?id=#{genre}"
		offset, old_count, count = 0, -1, 0
		# headers = {'Host'           => 'homeoftheunderdogs.net',
		# 					 'Referer'        => 'https://www.homeoftheunderdogs.net/',
		# 					 'Sec-Fetch-Site' => 'same-origin'}
		while old_count < count
			old_count = count

			raw = scanner.http_get "#{base}&offset=#{offset}"
			return if raw.nil?
			#File.open( '/Users/peter/temp/hotu.html', 'w') {|io| io.print raw}
			#raw = IO.read( '/Users/peter/temp/hotu.html')

			raw.scan( /href='game.php\?id=(\d+)'>([^<]*)</i) do |m|
				text = m[1]
				text.force_encoding( 'UTF-8')
				text.encode!( 'US-ASCII',
											:invalid => :replace, :undef => :replace, :universal_newline => true)
				text = text.sub( /\?$/, '')
				count = count + 1
				scanner.suggest_link(text, 'https://www.homeoftheunderdogs.net/game.php?id=' + m[0])
			end

			offset += 40
		end
	end

	def link_title( * titles)
		('Home of the Underdogs' == titles[0]) ? titles[1] : titles[0]
	end

	def name
		'HOTU'
  end

	def year_tolerance
		3
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			nodes.css( 'td.bodycopy') do |cell|
				digest['description'] = cell.text
			end

			nodes.css( 'big b') do |cell|
				digest['title'] = cell.text
			end

			get_anchors( nodes, 'Year:') do |year|
				digest['year'] = year.to_i
			end
			digest['developers']  = get_companies(nodes,'Developer:')
			digest['publishers']  = get_companies(nodes,'Publisher:')

			tags = []
			get_anchors( nodes, 'Theme:') do |tag|
				tags << tag.strip
			end
			digest['tags'] = tags.uniq
		end
	end

	def get_companies(nodes, type)
		[].tap do |companies|
			get_anchors( nodes, type) do |anchor|
				companies << anchor
			end
		end
	end

	def get_anchors(nodes, type)
		nodes.css('td.infoboxLeft') do |title|
			[title.text.strip]
		end.parent.css('td.infoboxRight a') do |anchor, header|
			if header == type
				yield anchor.text.strip
			end
		end
	end
end
