class GooglePlay
	include Common

	def accept( scanner, name, url)
		true
	end

	def cache_directory
		'google_play'
	end

	def search( name)
		name = name.gsub( /[^A-Za-z0-9]/, ' ').gsub( /\s+/, '%20')
		page = http_get( 'https://play.google.com/store/search?c=apps&q=' + name)
		urls = []
		app  = ''

		page.split( "\n").each do |line|
			if m = /^,"([^"]*)"/.match( line)
				app = m[1]
			elsif m1 = /^,\[null,null,.*"\/store\/apps\/details\?id\\u003d(games\..*)"/.match( line)
				urls << [app, "https://play.google.com/store/apps/details?id=#{m1[1]}"]
			end
		end

		urls
	end

	def title
		'Google Play'
	end

	def type
		'Store'
	end

	def urls( scanner, lifetime)
		path = scanner.cache + '/gog.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			loop, page, urls = true, 0, {}

			while (page < 200) && loop
				page += 1
				old_size = urls.size
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page}&sort=release_asc"

				raw.split( ' ng-href="').each do |line|
					if m = /^(\/game[^"]*)">[^>]*>([^<]*)</.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls[text] = 'https://www.gog.com' + m[1]
					end
				end

				loop = (urls.size != old_size)
			end

			raise "Too many GOG pages" if loop
			File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => urls})}
		end

		JSON.parse( IO.read( path))['urls']
	end
end
