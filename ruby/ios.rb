class IOS
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

	def get_ios_compatibility( scanner, url, id, reuse=true)
		path = "#{scanner.cache}/ios_pages/#{id}.html"

		unless File.exist?( path) && reuse
			html = scanner.http_get( url)
			sleep 10
			html.force_encoding( 'UTF-8')
			html.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			File.open( path, 'w') {|io| io.print html}
		else
			html = IO.read( path)
		end

		compatible, found = false, false
		html.gsub( /data-test-bidi>.*?<\/p/m) do |text|
			found = true
			compatible = true if /(iOS|iPadOS)/i =~ text
		end

		return found, compatible, html
	end

	def title
		'iOS'
	end

	def type
		'Store'
	end

	def urls( scanner, lifetime)
		urls, letters = {}, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ*'
		scanner.purge_files( scanner.cache + '/ios_pages', 200, 100)

		{'adventure':7002, 'puzzle':7012,'role-playing':7014}.each do |section, id|
			(0...letters.size).each do |i|
				path = scanner.cache + "/ios-#{section}#{i+1}.json"
				if File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
					JSON.parse( IO.read( path))['urls'].each_pair {|k,v| urls[k] = v}
					next
				end

				puts "... Scanning IOS #{section} apps letter #{letters[i..i]}"
				page, loop, letter_urls = 0, true, {}
				while loop && (page < 200)
					page += 1
					old_size = letter_urls.size
					raw = scanner.http_get( "https://apps.apple.com/us/genre/ios-games-#{section}/id#{id}?letter=#{letters[i..i]}&page=#{page}")
					sleep 15
					raw.split( '<li>').each do |line|
						if m = /<a href="(https:\/\/apps.apple.com\/us\/app\/[^"]*)">([^>]*)</.match(line)
							text = m[2]
							text.force_encoding( 'UTF-8')
							text.encode!( 'US-ASCII',
														:invalid => :replace, :undef => :replace, :universal_newline => true)
							letter_urls[text] = m[1]
							urls[text] = m[1]
						end
					end
					loop = (old_size < letter_urls.size)
				end

				raise "Too many IOS games" if loop
				File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => letter_urls})}
			end
		end
		# https://apps.apple.com/us/genre/ios-games/id6014?letter=A

		urls
	end
end
