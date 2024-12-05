require_relative 'digest_site'

class Steam < DigestSite
	def initialize
		@info         = nil
	end

	def coerce_url( url)
		if m = /^(https:\/\/store\.steampowered\.com\/app\/[0-9]*)($|\/)/.match( url)
			return m[1]
		end

		url.sub( '/agecheck/', '/')
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

	def get_aspects(pagoda, url, page)
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

	def get_game_description( page)
		if page.is_a?(String)
			''
		else
			super
		end
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

	def incremental( scanner)
		path  = scanner.cache + '/steam.json'
		raw   = JSON.parse( IO.read( path))['applist']['apps']
		count = 0

		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url = "https://store.steampowered.com/app/#{record['appid']}"
			scanner.debug_hook( 'Steam:urls', text, url)
			count += scanner.add_link( text, url)

			break if count >= 100
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

	def post_load(pagoda, url, page)
		@info = pagoda.get_yaml( 'steam.yaml') if @info.nil?
		tag_info = @info['tags']

		{}.tap do |digest|
			nodes = Nodes.parse(page)

			platforms = ['Steam']
			nodes.css('span.platform_img') do |platform|
				if m = /^platform_img (win|mac)$/.match(platform['class'])
					platforms << {'win' => 'Windows', 'mac' => 'Mac'}[m[1]]
				end
			end
			digest['platforms'] = platforms.uniq

			nodes.css('div.apphub_AppName') do |game_title|
				digest['title'] = game_title.text
			end

			nodes.css('div.release_date div.date') do |release_date|
				begin
					t = Date.parse(release_date).to_time
					if t <= Time.now
						digest['year'] = t.year
					end
				rescue StandardError
				end
			end

			digest['unreleased'] = true unless digest['year']

			if /English language not supported/ =~ page
				digest['unreleased'] = true
			end

			nodes.css('div.game_description_snippet') do |game_description|
				digest['description'] = game_description.text.strip
			end
			digest['developers']  = get_companies(nodes,'Developer:')
			digest['publishers']  = get_companies(nodes,'Publisher:')
			aspects               = []

			if /This content requires the base game/ =~ page
				aspects << "reject"
			end

			nodes.css('div.popular_tags a.app_tag') do |tag|
				action = tag_info[tag.text.strip]
				if action.nil?
					aspects << "Steam: #{tag.text.strip}"
				elsif action.is_a?(String)
					aspects << action
				else
					action.each {|a| aspects << a }
				end
			end
			digest['aspects'] = aspects.uniq
		end
	end

	def post_load_steamdb(pagoda, url, page)
		@info = pagoda.get_yaml( 'steam.yaml') if @info.nil?
		tag_info = @info['tags']

		{}.tap do |digest|
			nodes = Nodes.parse(page)

			platforms = []
			nodes.css('td.os-icons svg') do |platform|
				if m = /octicon-(windows|macos)/.match(platform['class'])
					platforms << {'windows' => 'Windows', 'macos' => 'Mac'}[m[1]]
				end
			end
			digest['platforms'] = platforms.uniq

			nodes.css('h1') do |h1|
				digest['title'] = h1.text if h1['itemprop'] == 'name'
			end

			nodes.css('td') { |td1| td1.text}.next_element do |label, td2|
				if label == 'Release Date'
					begin
						t = Date.parse(td2.text).to_time
						if t <= Time.now
							digest['year'] = t.year
						end
					rescue StandardError
						digest['year'] = nil
					end
				end
			end

			digest['unreleased'] = true unless digest['year']

			nodes.css('p.header-description') do |game_description|
				digest['description'] = game_description.text.strip
			end
			digest['developers']  = get_companies_steamdb(nodes,'Developer:')
			digest['publishers']  = get_companies_steamdb(nodes,'Publisher:')
			aspects               = []

			if /This content requires the base (game|application)/ =~ page
				aspects << "reject"
			end

			nodes.css('a.btn') do |tag|
				next unless /^\/tag\/\d+\/$/ =~ tag['href']
				action = tag_info[tag.text.strip]
				if action.nil?
					aspects << "Steamdb: #{tag.text.strip}"
				elsif action.is_a?(String)
					aspects << action
				else
					action.each {|a| aspects << a }
				end
			end
			digest['aspects'] = aspects.uniq
		end
	end

	def reduce_title( title)
		if m = /^(.+) on Steam$/.match( title)
			title = m[1]
		end
		title.strip
	end

	def year_tolerance
		1
	end

	def get_companies(nodes, type)
		[].tap do |companies|
			nodes.css('div.dev_row div.subtitle') do |title|
				[title.text.strip]
			end.parent.css('a') do |anchor, header|
				if header == type
					companies << anchor.text.strip
				end
			end
		end
	end

	def get_companies_steamdb(nodes, type)
		[].tap do |companies|
			nodes.css('td') do |title|
				[title.text.strip]
			end.parent.css('a') do |anchor, header|
				if header == type
					companies << anchor.text.strip
				end
			end
		end
	end

	def digest_link(pagoda, url)
		status, response = http_get_threaded(url)

		unless status
			return status, response
		end

		if response.is_a? Net::HTTPSuccess
			return status, post_load(pagoda, url, response.body)
		end

		if (response.is_a? Net::HTTPRedirection) &&
				(/agecheck/ =~ response['location'])
			begin
				driver = browser_driver
				driver.navigate.to response['location']
				sleep 10

				begin
					year_select = driver.find_element(id:'ageYear')
					year_select.send_keys('1990')
				rescue Selenium::WebDriver::Error::NoSuchElementError
					return true, {'aspects' => ['reject']}
				end

				begin
					button = driver.find_element(id:'view_product_page_btn')
				rescue Selenium::WebDriver::Error::NoSuchElementError
					return true, {'aspects' => ['reject']}
				end

				button.click
				sleep 10
				body = driver.execute_script('return document.documentElement.outerHTML;')
				return true, post_load(pagoda, url, body)
			rescue StandardError => bang
				return false, bang.message
			end
			# return true, {'aspects' => ['accept']}
		end

		if response.is_a? Net::HTTPRedirection
			return false, "Redirected to #{response['location']}"
		end

		return false, response.message
	end
end
