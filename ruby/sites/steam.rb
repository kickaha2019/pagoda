class Steam
	def complete?( scanner)
		true
	end

	def find( scanner)
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
			url = "https://store.steampowered.com/app/#{record['appid']}"
			suggest( text, url)
			scanner.debug_hook( 'Steam:urls', text, url)
		end
	end
end
