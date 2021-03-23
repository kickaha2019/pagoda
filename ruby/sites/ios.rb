class IOS
	@@sections = {'adventure':7002, 'puzzle':7012,'role-playing':7014}
	@@letters  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ*'

	def accept( scanner, name, url)
		if m = /\/id(\d+)($|\?)/.match( url)
			begin
				found, compatible, html = get_ios_compatibility( scanner, url, m[1])

				unless found
					found, compatible, html = get_ios_compatibility( scanner, url, m[1], false)
				end

				unless found
					error( "Compatibility section not found on #{url} for #{name}")
					File.open( scanner.cache + '/ios_compatibility_not_found.html', 'w') do |io|
						io.puts html
					end
				end

				compatible
			rescue Exception => bang
				scanner.error( "Error getting #{name}: #{url}: #{bang.message}")
				false
			end
  	else
			scanner.error( "Unexpected URL for #{name}: #{url}")
	  	false
		end
	end

	def complete?( scanner)
		true
	end

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

	# def get_ios_compatibility( scanner, url, id, reuse=true)
	# 	path = "#{scanner.cache}/ios_pages/#{id}.html"
	#
	# 	unless File.exist?( path) && reuse
	# 		html = scanner.http_get( url)
	# 		sleep 10
	# 		html.force_encoding( 'UTF-8')
	# 		html.encode!( 'US-ASCII',
	# 									:invalid => :replace, :undef => :replace, :universal_newline => true)
	# 		File.open( path, 'w') {|io| io.print html}
	# 	else
	# 		html = IO.read( path)
	# 	end
	#
	# 	compatible, found = false, false
	# 	html.gsub( /data-test-bidi>.*?<\/p/m) do |text|
	# 		found = true
	# 		compatible = true if /(iOS|iPadOS)/i =~ text
	# 	end
	#
	# 	return found, compatible, html
	# end

	def find( scanner, page, lifetime, url2link)
		Dir.entries( scanner.cache + '/ios').each do |f|
			if /^ios\-.*\.json$/ =~ f
				JSON.parse( IO.read( scanner.cache + '/ios/'+ f))['urls'].each_pair do |url,name|
					url2link[url] = {site:title, type:type, title:name, url:url}
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

	def title
		'iOS'
	end

	def type
		'Store'
	end
end
