require_relative 'default_site'

class Steam < DefaultSite
	def initialize
		@info         = nil
		@info_changed = 0
	end

	def coerce_url( url)
		if m = /^(https:\/\/store\.steampowered\.com\/app\/[0-9]*)($|\/)/.match( url)
			return m[1]
		end

		url.sub( '/agecheck/', '/')
	end

	def complete?( scanner)
		true
	end

	def correlate_url( url)  # https://store.steampowered.com/app/1092660/Blair_Witch/
		if m = /^(https:\/\/store\.steampowered\.com\/(?:app|bundle)\/[0-9]*)($|\/)/.match( url)
			return "Steam", "Store", m[1]
		end
		return nil, nil, nil
	end

	def find( scanner)
		path = scanner.cache + '/steam.json'

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end

			stats = scanner.get_scan_stats( name, 'Store')
			stats['count'] = JSON.parse( IO.read( path))['applist']['apps'].size
			scanner.put_scan_stats( name, 'Store', stats)
		end

		raw = JSON.parse( IO.read( path))['applist']['apps']
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url = "https://store.steampowered.com/app/#{record['appid']}"
			scanner.suggest_link( text, url)
			scanner.debug_hook( 'Steam:urls', text, url)
		end

		scanner.purge_lost_urls
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*) on Steam$/.match( rec[:title].strip)
			rec[:title] = m[1]

			tags = get_tags( page)
			if tags.size > 0
				@info = pagoda.get_yaml( 'steam.yaml') if @info.nil?
				tag_info = @info['tags']
				rec[:ignore] = true

				tags.each do |tag|
					action = tag_info[tag]
					action = action[0] if action.is_a?( Array)

					if action == 'accept'
						rec[:ignore] = false
					elsif action.nil?
						tag_info[tag] = 'ignore'
						@info_changed += 1
					end
				end

				tags.each do |tag|
					if tag_info[tag] == 'reject'
						#p tag
						rec[:ignore] = true
					end
				end
			end

			rec[:ignore] = true unless rec[:year]
			return true
		end

		rec[:ignore] = true
		return true if /\/agecheck\/app\//  =~ link.url
		return true if /^Site Error$/       =~ rec[:title]
		return true if /^Welcome to Steam$/ =~ rec[:title]
		rec[:valid] = false
		false
	end

	def get_aspects(pagoda, page)
		@info = pagoda.get_yaml( 'steam.yaml') if @info.nil?
		tags  = @info['tags']

		get_tags( page).each do |tag|
			action = tags[tag]
			action = [action] unless action.is_a?(Array)
			action.each do |aspect|
				yield aspect unless ['accept','reject','ignore'].include?( aspect)
			end
		end
	end

	def get_derived_aspects( page)
		yield 'Steam'
		if /data-os="win"/m =~ page
			yield 'Windows'
		end
		if /data-os="mac"/m =~ page
			yield 'Mac'
		end
	end

	def get_game_description( page)
		''
	end

	def get_game_details( url, page, game)
		publisher, developer, release = false, false, false
		page.split("<div").each do |line|
			if />Publisher:<\/div/ =~ line
				#p ['get_game_details1', line]
				publisher = true
			elsif />Developer:<\/div/ =~ line
				#p ['get_game_details2', line]
				developer = true
			elsif />Release Date:<\/div/ =~ line
				#p ['get_game_details3', line]
				release = true
			elsif m = />([^<]+)<\//.match( line)
				text = m[1].gsub( '&nbsp;', ' ')
				#p ['get_game_details4', text]
				if publisher
					game[:publisher] = text
				elsif developer
					game[:developer] = text
				elsif release
					if m2 = /(\d\d) (\w\w\w), (\d\d\d\d)$/m.match( text)
						if (month = decode_month( m2[2])) > 0
							d = Time.new( m2[3].to_i, month, m2[1].to_i)
							game[:year] = d.year if d <= Time.now
						end
					end
				end
				publisher, developer, release = false, false, false
			end
		end
	end

	def get_tags( page)
		tags = []
		page.scan( /<a\s+href="https:\/\/store.steampowered.com\/tags\/en\/[^>]*>([^<]*)</) do |tag|
			tags << tag[0].strip
		end
		tags
	end

	def ignore_redirects?
		true
	end

	def incremental( scanner)
		path  = scanner.cache + '/steam.json'
		raw   = JSON.parse( IO.read( path))['applist']['apps']
		count = 0

		# raw.each do |record|
		# 	text = record['name']
		# 	text.force_encoding( 'UTF-8')
		# 	text.encode!( 'US-ASCII',
		# 								:invalid => :replace, :undef => :replace, :universal_newline => true)
		# 	url = "https://store.steampowered.com/app/#{record['appid']}"
		# 	scanner.patch_orig_title( url, text)
		# end
		# raise 'Dev'

		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url = "https://store.steampowered.com/app/#{record['appid']}"
			scanner.debug_hook( 'Steam:urls', text, url)
			count += scanner.add_link( text, url)

			break if count >= 150
		end

		count
	end

	def name
		'Steam'
	end

	def override_verify_url( url)
		if /\/agecheck\// =~ url
			return true, true, nil, 'Age check'
		end
		return false, false, nil, ''
	end

	def terminate( pagoda)
		if @info_changed > 0
			pagoda.put_yaml( @info, 'steam.yaml')
			puts "... #{@info_changed} tags added to steam.yaml"
		end
	end

	def year_tolerance
		1
	end
end
