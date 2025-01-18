require_relative 'default_site'

class Grabbed < DefaultSite
	def incremental( scanner, _)
		path  = scanner.cache + "/grabbed.txt"
		added = 0
		game  = -1
		left  = []

		IO.readlines( path).each do |line|
			url = line.strip
			next if url == ''

			if /^\d+$/ =~ url
				game = url.to_i
				next
			end

			title = (game > 0) ? scanner.game_title(game) : 'Unknown'
			site, type, link = * scanner.correlate_site( url)

			if site
				if scanner.add_or_replace_link( title, link, site, type) > 0
					added += 1
					scanner.add_bind(link, game) if game >= 0
					game = -1
				end
			else
				added += scanner.add_link( title, url)
				left << url
			end
		end

		File.open( path, 'w') do |io|
			io.print left.join( '')
		end

		added
	end

	def name
		'Grabbed'
	end
end
