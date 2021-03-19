class Steam
	def complete?
		true
	end

	def find( scanner, page, lifetime, url2link)
		return if page > 0
		path = scanner.cache + '/steam.json'

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end
		end

		raw = JSON.parse( IO.read( path))['applist']['apps']
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url2link[url] = {site:title,
											 type:type,
											 title:text,
											 url:"https://store.steampowered.com/app/#{record['appid']}"}
			scanner.debug_hook( 'Steam:urls', text, urls[-1][1])
		end
	end

	def title
		'Steam'
	end

	def type
		'Store'
	end
end
