require_relative 'default_site'

class Grabbed < DefaultSite
	def incremental( scanner)
		path  = scanner.cache + "/grabbed.txt"
		added = 0
		game  = -1

		left = IO.readlines( path).select do |line|
			url = line.strip
			next if url == ''

			if /^\d+$/ =~ url
				game = url.to_i
				next
			end

			title, error = 'Unknown', nil
			begin
				raw   = scanner.http_get url
				if m = /<title>([^<]*)<\/title>/mi.match( raw)
					title = m[1].strip
				elsif game > 0
					title = scanner.game_title(game)
				end
			rescue StandardError => e
				error = e.message
			end
			
			site, type, link = * scanner.correlate_site( url)
			if site
				if scanner.add_or_replace_link( title, link, site, type) > 0
					added += 1
					scanner.add_bind(link, game) if game >= 0
					game = -1
				end
			else
				added += scanner.add_link( title, url)
			end

			if error && (link = scanner.get_link(url))
				link.complain(error)
			end
		end

		File.open( path, 'w') do |io|
			io.print left.join( '')
		end

		# scanner.get_links do |title, url|
		# 	site, type, link = * scanner.correlate_site( url)
		# 	if site
		# 		scanner.update_new_link(url, site, type, title, link)
		# 	end
		# end

		added
	end

	def name
		'Grabbed'
	end
end
