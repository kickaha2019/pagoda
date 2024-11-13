require_relative 'digest_site'

class Igdb < DigestSite
	include Common

	def initialize
		@info         = nil
		@access_token = nil
	end

	def coerce_url( url)
		url.split('/?')[0]
	end

	def correlate_url( url)
		if %r{^https://www\.igdb\.com/games/} =~ url
			return 'IGDB', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def get_aspects(pagoda, url, page)
		unless page.is_a?(String)
			super {|aspect| yield aspect}
			return
		end

		begin
			info = get_json(page)
			tag_to_aspects(pagoda, info, 'game_modes')          {|aspect| yield aspect}
			tag_to_aspects(pagoda, info, 'genres')              {|aspect| yield aspect}
			tag_to_aspects(pagoda, info, 'player_perspectives') {|aspect| yield aspect}
			tag_to_aspects(pagoda, info, 'themes')              {|aspect| yield aspect}
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
		end
	end

	def get_game_description(url, page)
		unless page.is_a?(String)
			return super
		end

		begin
			get_json(page)['summary']
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
			''
		end
	end

	def get_game_details( url, page, game)
		unless page.is_a?(String)
			super
			return
		end

		begin
			info = get_json(page)

			if frd = info['first_release_date']
				game[:year] = Time.at(frd).year
			elsif rd = info['release_dates']
				game[:year] = rd.first['y']
				rd[1..-1].each do |date|
					game[:year] = date['y'] if date['y'] < game[:year]
				end
			end

			if companies = info['involved_companies']
				developers = companies.select {|c| c['developer']}
				unless developers.empty?
					game[:developer] = developers.collect {|c| c['company']['name']}.join(',')
				end

				publishers = companies.select {|c| c['publisher']}
				unless publishers.empty?
					game[:publisher] = publishers.collect {|c| c['company']['name']}.join(',')
				end
			end

		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
		end
	end

	def get_json(page)
		json = JSON.parse(page)
		json.empty? ? [] : json[0]
	end

	def get_title(url, page, defval)
		unless page.is_a?(String)
			return super
		end

		begin
			get_json(page)['name']
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
			defval
		end
	end

	def tag_to_aspects(pagoda, data, key)
		return if data[key].nil?
		@info = pagoda.get_yaml( 'igdb.yaml') if @info.nil?

		data[key].each do |item|
			aspects = @info['tags'][item['name']]
			if aspects.nil?
				yield "IGDB unhandled: #{item['name']}"
			elsif aspects.is_a? Array
				aspects.each {|aspect| yield aspect}
			else
				yield aspects
			end
		end
	end

	def name
		'IGDB'
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
		return '[{}]' unless m

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

		{}.tap do |digest|
			digest['title']       = info['name']
			digest['year']        = get_json_year(info)
			digest['description'] = info['summary'] || info['storyline']
			digest['developers']  = get_json_companies(info,'developer')
			digest['publishers']  = get_json_companies(info,'publisher')
			digest['aspects']     = []
			get_aspects(pagoda, url, json) do |aspect|
				digest['aspects'] << aspect
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
