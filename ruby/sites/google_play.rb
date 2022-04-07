class GooglePlay
	include Common

	def check_child_link( url, text, anchor)
	end

	def cache_directory
		'google_play'
	end

	def find( scanner)
		dir  = scanner.cache + '/' + cache_directory
		found = {}

		Dir.entries( dir).each do |f|
			if /\.json$/ =~ f
				searched = JSON.parse( IO.read( dir + '/' + f))
				searched.each do |rec|
					scanner.suggest_link( rec[0], rec[1])
				end
			end
		end

		scanner.purge_lost_urls( /^https:\/\/play\.google\.com\//)
	end

	def get_game_description( page)
		''
	end

	def get_game_details( url, page, game)
	end

	def search( searcher)
		searcher.search( cache_directory, 50) do |game_name|
			search_for_name( game_name)
		end
		0
	end

	def search_for_name( name)
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
end
