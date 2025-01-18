require_relative 'default_site'

class Steam < DefaultSite
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

	def incremental( scanner)
		raw = scanner.curl('https://api.steampowered.com/ISteamApps/GetAppList/v2/')
		suggested = {}

		JSON.parse(raw)['applist']['apps'].each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			url = "https://store.steampowered.com/app/#{record['appid']}"
			suggested[url] = true
			scanner.suggest_link('All', text, url)
		end

		scanner.already_suggested['All'].each do |url|
			scanner.delete_suggest(url) unless suggested[url]
		end
	end

	def name
		'Steam'
	end

	def post_load(pagoda, url, page)
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
					if t <= pagoda.now
						digest['year'] = t.year
					end
				rescue StandardError
				end
			end

			digest['unreleased'] = true unless digest['year']

			if /English language not supported/ =~ page
				digest['unreleased'] = true
			elsif /This content requires the base game/ =~ page
				digest['unreleased'] = true
			elsif /but does not include the base game/ =~ page
				digest['unreleased'] = true
			end

			nodes.css('div.game_description_snippet') do |game_description|
				digest['description'] = game_description.text.strip
			end
			digest['developers']  = get_companies(nodes,'Developer:')
			digest['publishers']  = get_companies(nodes,'Publisher:')
			aspects               = []

			nodes.css('div.popular_tags a.app_tag') do |tag|
				aspects << tag.text.strip
			end
			digest['tags'] = aspects.uniq
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

	def digest_link(pagoda, url)
		status, response = http_get_threaded(url)

		unless status
			return status, false, response
		end

		if response.is_a? Net::HTTPSuccess
			return status, false, post_load(pagoda, url, response.body)
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
					return true, false, {'unreleased' => true}
				end

				begin
					button = driver.find_element(id:'view_product_page_btn')
				rescue Selenium::WebDriver::Error::NoSuchElementError
					return true, false, {'unreleased' => true}
				end

				button.click
				sleep 10
				body = driver.execute_script('return document.documentElement.outerHTML;')
				return true, false, post_load(pagoda, url, body)
			rescue StandardError => bang
				return false, false, bang.message
			end
		end

		if response.is_a? Net::HTTPRedirection
			return false, true, "Redirected to #{response['location']}"
		end

		return false, false, response.message
	end
end
