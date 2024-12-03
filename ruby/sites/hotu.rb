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

		stats = scanner.get_scan_stats( name, 'Reference')
		stats['count'] = urls.size
		scanner.put_scan_stats( name, 'Reference', stats)
	end

	def find_from( scanner, base, urls)
		offset, old_count = 0, -1

		while (old_count < urls.size)
			old_count = urls.size

			raw = scanner.http_get "#{base}&offset=#{offset}"
			#File.open( '/Users/peter/temp/hotu.html', 'w') {|io| io.print raw}
			#raw = IO.read( '/Users/peter/temp/hotu.html')

			raw.scan( /href='game.php\?id=(\d+)'>([^<]*)</i) do |m|
				text = m[1]
				text.force_encoding( 'UTF-8')
				text.encode!( 'US-ASCII',
											:invalid => :replace, :undef => :replace, :universal_newline => true)
				text = text.sub( /\?$/, '')
				urls['https://www.homeoftheunderdogs.net/game.php?id=' + m[0]] = text
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
		@info    = pagoda.get_yaml( 'hotu.yaml') if @info.nil?
		tag_info = @info['tags']
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

			aspects = ['accept']
			get_anchors( nodes, 'Theme:') do |tag|
				action = tag_info[tag.strip]
				if action.nil?
					aspects << "HOTU: #{tag.strip}"
				elsif action.is_a?(String)
					aspects << action
				else
					action.each {|a| aspects << a}
				end
			end
			digest['aspects'] = aspects.uniq
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
