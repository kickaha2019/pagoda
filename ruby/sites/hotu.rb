require_relative 'default_site'

class Hotu < DefaultSite
	def find( scanner)
		path = scanner.cache + "/hotu.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			offset, urls, old_count = 0, {}, -1

			find_from( scanner, 'http://www.homeoftheunderdogs.net/genre.php?id=3', urls)
			find_from( scanner, 'http://www.homeoftheunderdogs.net/genre.php?id=6', urls)
			find_from( scanner, 'http://www.homeoftheunderdogs.net/genre.php?id=7', urls)

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
				urls['http://www.homeoftheunderdogs.net/game.php?id=' + m[0]] = text
			end

			offset += 40
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'HOTU'
  end
end
