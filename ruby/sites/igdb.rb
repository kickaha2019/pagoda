require_relative 'default_site'

class Igdb < DefaultSite
	include Common

	def initialize
		@info         = nil
		@access_token = nil
	end

	def correlate_url( url)
		if %r{^https://www\.igdb\.com/games/} =~ url
			return 'IGDB', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def get_aspects(pagoda, url, page)
		begin
			info = JSON.parse(page)[0]
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
		begin
			JSON.parse(page)[0]['summary']
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
			''
		end
	end

	def get_game_details( url, page, game)
		begin
			info = JSON.parse(page)[0]
			game[:year] = Time.at(info['first_release_date']).year
		rescue StandardError => e
			puts e.backtrace.join("\n")
			puts "*** #{url}: #{e.message}"
		end
	end

	def get_game_title( url, page, defval)
		begin
			JSON.parse(page)[0]['name']
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

	def post_load(pagoda, page)
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
			'name',
			'player_perspectives.name',
			'storyline',
			'summary',
			'themes.name'
		]
		http_post( 'https://api.igdb.com/v4/games',
							 10,
							 {'Client-ID'    =>  twitch['client_id'],
											 'Authorization' => "Bearer #{@access_token}"},
							 "fields #{fields.join(',')}; where id=#{m[1]};")
	end
end
