class GooglePlay
	include Common

	def cache_directory
		'google_play'
	end

	def complete?
		true
	end

	def find( scanner, page, lifetime, url2link)
		return if page > 0
		dir  = scanner.cache + '/' + cache_directory
		found = {}

		Dir.entries( dir).each do |f|
			if /\.json$/ =~ f
				searched = JSON.parse( IO.read( dir + '/' + f))
				searched.each do |rec|
					found[rec[1]] = rec[0]
				end
			end
		end

		found.keys.each do |url|
			url2link[url] = {site:title, type:type, title:found[url], url:url}
		end
	end

	def search( name)
		name = name.to_s.gsub( /[^A-Za-z0-9]/, ' ').gsub( /\s+/, '%20')
		page = http_get( 'https://play.google.com/store/search?c=apps&q=' + name, 60)
		urls = []
		app  = ''

		page.split( "\n").each do |line|
			if m = /^,"([^"]*)"/.match( line)
				app = m[1]
				app.force_encoding( 'UTF-8')
				app.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			elsif m1 = /"\/store\/apps\/details\?id\\u003d([^"]*)"/.match( line)
				urls << [app, "https://play.google.com/store/apps/details?id=#{m1[1]}"] if app
				app = nil
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
end
