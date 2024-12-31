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

	def find( scanner)
		path = scanner.cache + "/hotu.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			offset, urls, old_count = 0, {}, -1

			find_from( scanner, 'https://www.homeoftheunderdogs.net/genre.php?id=3', urls)
			find_from( scanner, 'https://www.homeoftheunderdogs.net/genre.php?id=6', urls)
			find_from( scanner, 'https://www.homeoftheunderdogs.net/genre.php?id=7', urls)

			# if urls.size < 1000
			# 	scanner.error( 'Not enough URLs found for ' + name)
			# end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		urls = JSON.parse( IO.read( path))
		urls.each_pair do |url, name|
			scanner.suggest_link( name, url)
		end
	end

	def find_from( scanner, base, urls)
		offset, old_count = 0, -1

		while old_count < urls.size
			old_count = urls.size

			scanner.html_anchors("#{base}&offset=#{offset}") do |link, label|
				return 0 unless /game.php\?id=/ =~ link
				label.force_encoding( 'UTF-8')
				label.encode!( 'US-ASCII',
											 :invalid => :replace, :undef => :replace, :universal_newline => true)
				label = label.sub( /\?$/, '')
				urls['https://www.homeoftheunderdogs.net/' + link] = label
				1
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
