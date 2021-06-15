class TouchArcade
	def find( scanner)
		path = scanner.cache + "/touch_arcade.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			urls, page, old_count = {}, 0, -1

			while old_count < urls.size
				old_count = urls.size
				begin
					raw = scanner.http_get "https://toucharcade.com/category/reviews/page/#{page+1}"
				rescue Exception => bang
					break
				end

				raw.split( "\n").each do |line|
					if m = /<a href=\"([^"]*)\" rel=\"bookmark\">([^<]*)<\/a>/.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls[m[1]] = text
					end
				end

				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.add_link( name, url)
		end
	end

	def incremental( scanner)
		# path   = scanner.cache + "/touch_arcade.json"
		# cached = {} # JSON.parse( IO.read( path))
		# added  = false

		scanner.html_links( 'https://toucharcade.com/category/reviews/') do |link|
			if /^https:\/\/toucharcade\.com\/.*-review(-|\/)/ =~ link
				link = link.split('?')[0]
				scanner.add_link( link, link)
				# unless cached[link]
				# 	cached[link] = ''
				# 	added = true
				# end
			else
				0
			end
		end

		# scanner.twitter_feed_links( 'toucharcade') do |link|
		# 	if /^https:\/\/toucharcade\.com\/.*-review(-|\/)/ =~ link
		# 		link = link.split('?')[0]
		# 		unless cached[link]
		# 			puts link
		# 			cached[link] = ''
		# 			added = true
		# 		end
		# 	end
		# end

		# if true
		# 	File.open( path, 'w') {|io| io.print JSON.generate( cached)}
		# end
	end
end
