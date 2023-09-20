require_relative 'default_site'

class MobyGames < DefaultSite
	def find( scanner)
		path = scanner.cache + "/mobygames.json"
		if File.exist?( path)
			JSON.parse( IO.read( path)).each_pair do |url, name|
				scanner.suggest_link( name, url)
			end
		end
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*)- MobyGames/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_game_description( page)
		desc, in_desc = [], false
		page.split( "<h2>").each do |line|
			return line if /^Description/ =~ line
		end
		page
	end

	def get_game_details( url, page, game)
		publisher, developer, release = false, false, false
		page.split("<div").each do |line|
			if />Published\s+by</ =~ line
				#p ['get_game_details1', line]
				publisher = true
			elsif />Developed\s+by</ =~ line
				#p ['get_game_details2', line]
				developer = true
			elsif />Released</ =~ line
				#p ['get_game_details3', line]
				release = true
			elsif m = />([^<]*)<\/a>/.match( line)
				text = m[1].gsub( '&nbsp;', ' ')
				#p ['get_game_details4', text]
				if publisher
					game[:publisher] = text
				elsif developer
					game[:developer] = text
				elsif release
					if m2 = /(\d\d\d\d)$/m.match( text)
						game[:year] = m2[1]
					end
				end
				publisher, developer, release = false, false, false
			end
		end
	end

	def incremental( scanner)
		path = scanner.cache + "/mobygames.json"
		urls = {}

		if File.exist?( path)
			urls = JSON.parse( IO.read( path))
		end

		incremental1( scanner, 'adventure', urls)
		incremental1( scanner, 'role-playing-rpg', urls)

		File.open( path, 'w') do |io|
			io.print JSON.generate( urls)
		end

		0
	end

	def incremental1( scanner, genre, urls)
		incremental2( scanner, genre, 'added', 1, urls)

		stats = scanner.get_scan_stats( name, genre)
		page  = stats['page'] ? stats['page'].to_i : 1
		(0..9).each do
		  page = incremental2( scanner, genre, 'title', page, urls)
		end

		stats['page'] = page
		scanner.put_scan_stats( name, genre, stats)
	end

	def incremental2( scanner, genre, sort, page, urls)
		raw   = scanner.http_get "https://www.mobygames.com/game/genre:#{genre}/sort:#{sort}/page:#{page}/"

		if m = /initial-values='([^']*)'/m.match( raw)
			json = JSON.parse( m[1])
			json['games'].each do |game|
				title, url = game['title'], game['internal_url']
				urls[url] = title
			end

			if page * json['perPage'] > json['total']
				page = 1
			else
				page += 1
			end
		else
			raise 'Data not found'
		end

		page
	end

	def name
		'MobyGames'
	end

	def tag_aspects( pagoda, page)
		if page.include? 'https://www.mobygames.com/genre/sheet/1st-person/'
			yield '1st person'
		end

		if page.include? 'https://www.mobygames.com/genre/sheet/3rd-person/'
			yield '3rd person'
		end

		if page.include? 'https://www.mobygames.com/genre/sheet/side-view/'
			yield '3rd person'
		end
	end
end
