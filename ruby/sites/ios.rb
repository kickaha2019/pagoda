class IOS
	@@sections = {'adventure':7002, 'puzzle':7012,'role-playing':7014}
	@@letters  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ*'

	def get_cache_info( searcher)
		info = []
		@@sections.each_key do |section|
			@@letters.each_char do |letter|
				path = get_cache_path( searcher, section, letter)
				t = 0
				if File.exist?( path)
					t = File.mtime( path).to_i
				end
				info << [section, letter, t]
			end
		end
		info
	end

	def get_cache_path( searcher, section, letter)
		index = @@letters.index( letter)
		searcher.cache + "/ios/#{section}#{index+1}.json"
	end

	def find( scanner)
		Dir.entries( scanner.cache + '/ios').each do |f|
			if /^ios\-.*\.json$/ =~ f
				JSON.parse( IO.read( scanner.cache + '/ios/'+ f))['urls'].each_pair do |url,name|
					scanner.suggest_link( name, url)
				end
			end
		end
	end

	def refresh_cache( searcher, section, letter)
		path = get_cache_path( searcher, section, letter)

		puts "... Scanning IOS #{section} apps letter #{letter}"
		page, loop, letter_urls = 0, true, {}
		while loop && (page < 200)
			page += 1
			old_size = letter_urls.size
			raw = searcher.http_get( "https://apps.apple.com/us/genre/ios-games-#{section}/id#{@@sections[section]}?letter=#{letter}&page=#{page}")
			sleep 15
			raw.split( '<li>').each do |line|
				if m = /<a href="(https:\/\/apps.apple.com\/us\/app\/[^"]*)">([^>]*)</.match(line)
					text = m[2]
					text.force_encoding( 'UTF-8')
					text.encode!( 'US-ASCII',
												:invalid => :replace, :undef => :replace, :universal_newline => true)
					letter_urls[m[1]] = text
				end
			end
			loop = (old_size < letter_urls.size)
		end

		raise "Too many IOS games" if loop
		File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => letter_urls})}
	end

	def search( searcher)
		caches = get_cache_info( searcher).sort_by {|cache| cache[2]}
		caches[0..2].each do |cache|
			refresh_cache( searcher, cache[0], cache[1])
		end
	end
end
