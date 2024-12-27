require_relative 'default_site'

class Igdb < DefaultSite
	def initialize
		@info         = nil
		@access_token = nil
	end

	def coerce_url( url)
		url.split('?')[0]
	end

	def correlate_url( url)
		if %r{^https://www\.igdb\.com/games/} =~ url
			return 'IGDB', 'Reference', url.split('?').first
		else
			return nil, nil, nil
		end
	end

	def get_tags(url, info, tags)
		begin
			get_tags_from(info, 'game_modes', tags)
			get_tags_from(info, 'genres', tags)
			get_tags_from(info, 'player_perspectives', tags)
			get_tags_from(info, 'themes', tags)
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
		end
	end

	def get_json(page)
		json = JSON.parse(page)
		json.empty? ? [] : json[0]
	end

	def get_tags_from(data, key, tags)
		return if data[key].nil?

		data[key].each do |item|
			tags << item['name']
		end
	end

	def name
		'IGDB'
	end

	def digest_link(pagoda, url)
		status, response = http_get_threaded(url)
		if status
			return true, false, post_load(pagoda, url, response.body)
		end

		File.open( '/Users/peter/Caches/Pagoda/igdb.html', 'w') do |io|
			io.print response.body
		end
		return false, false, response.message
	end

	def post_load(pagoda, url, page)
		twitch = pagoda.settings['Twitch']

		if @access_token.nil?
			url = [
				'https://id.twitch.tv/oauth2/token',
				"?client_id=#{twitch['client_id']}",
				"&client_secret=#{twitch['client_secret']}",
				'&grant_type=client_credentials'
			].join
			@access_token = JSON.parse(http_post( url, 10))['access_token']
		end

		m = /data-game-id="(\d+)"/.match(page)
		return {} unless m

		fields = [
			'game_modes.name',
			'first_release_date',
			'genres.name',
			'involved_companies.company.name',
			'involved_companies.developer',
			'involved_companies.publisher',
			'name',
			'player_perspectives.name',
			'release_dates.y',
			'storyline',
			'summary',
			'themes.name'
		]

		json = http_post( 'https://api.igdb.com/v4/games',
							 10,
							 {'Client-ID'    =>  twitch['client_id'],
											 'Authorization' => "Bearer #{@access_token}"},
							 "fields #{fields.join(',')}; where id=#{m[1]};")
		info = JSON.parse(json)[0]
		return {} if info.nil?

		{}.tap do |digest|
			digest['title']       = info['name']
			digest['year']        = get_json_year(info)
			digest['description'] = info['summary'] || info['storyline']
			digest['developers']  = get_json_companies(info,'developer')
			digest['publishers']  = get_json_companies(info,'publisher')
			digest['tags']        = [].tap do |tags|
				get_tags(url, info, tags)
			end
		end
	end

	def get_json_companies(info,type)
		if companies = info['involved_companies']
			companies = companies.select {|c| c[type]}
			if companies.empty?
				[]
			else
				companies.collect {|c| c['company']['name']}
			end
		else
			[]
		end
	end

	def get_json_year(info)
		if frd = info['first_release_date']
			Time.at(frd).year
		elsif rd = info['release_dates']
			year = rd.first['y']
			rd[1..-1].each do |date|
				year = date['y'] if date['y'] < year
			end
			year
		else
			nil
		end
	end
end
