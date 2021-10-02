class GOG
	def find( scanner)
		path = scanner.cache + "/gog.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			urls, page, old_count = {}, 0, -1

			while old_count < urls.size
				old_count = urls.size
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page+1}&sort=release_asc"

				raw.split( ' ng-href="').each do |line|
					if m = /^(\/game[^"]*)">[^>]*>([^<]*)</.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls['https://www.gog.com' + m[1]] = text
					end
				end

				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.suggest_link( name, url)
		end

		scanner.purge_lost_urls( /^https:\/\/www\.gog\.com\//)
	end

	def incremental( scanner)
		# puts "*** Awaiting full scan to be done"
		# return
		path   = scanner.cache + "/gog.json"
		cached = JSON.parse( IO.read( path))

		added = scanner.twitter_feed_links( 'gogcom') do |text, link|
			if /^https:\/\/www\.gog\.com\/game\// =~ link
				link = link.split('?')[0]
				if cached[link]
					0
				else
					cached[link] = ''
					1
				end
			else
				0
			end
		end

		if added > 0
			File.open( path, 'w') {|io| io.print JSON.generate( cached)}
		end
		added
	end
end
