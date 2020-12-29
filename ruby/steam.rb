class Steam
	def accept( scanner, name, url)
		true
	end

	def title
		'Steam'
	end

	def type
		'Store'
	end

	def urls( scanner)
		path = scanner.cache + '/steam.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - 20 * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end
		end
		raw = JSON.parse( IO.read( path))['applist']['apps']
		urls = {}
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			urls[text] = "https://store.steampowered.com/app/#{record['appid']}"
		end
		urls
	end
end
