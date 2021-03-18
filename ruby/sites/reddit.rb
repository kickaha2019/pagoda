class Reddit
	include Common

	def find( scanner, page, lifetime, url2link)
		return if page > 0
		path = scanner.cache + '/reddit.json'

		unless File.exist?( path) && (File.mtime( path) > (Time.now - lifetime * 24 * 60 * 60))
			body = http_get( 'https://www.reddit.com/r/iosgaming/new.json',
											 10,
											 'Accept' => 'application/json')
			File.open( '/Users/peter/temp/reddit.json', 'w') {|io| io.print body}
			raise 'Dev'
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
end
