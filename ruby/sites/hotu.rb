require_relative 'default_site'

class Hotu < DefaultSite
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

	def get_game_description( page)
		Nodes.parse( page).css( 'td.bodycopy') do |cell|
			return cell.text
		end
		''
	end

	def get_game_details( url, page, game)
		publisher, developer, year = false, false, false
		page.split("\n").each do |line|
			if m = />([a-z0-9 ]*)<\/a>/i.match( line)
				game[:publisher] = m[1] if publisher
				game[:developer] = m[1] if developer
				game[:year]      = m[1].to_i if year
			end
			publisher, developer, year = false, false, false
			publisher = true if />Publisher:</.match( line )
			developer = true if />Developer:</.match( line )
			year = true if />Year:</.match( line )
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
end
