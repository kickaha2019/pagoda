=begin
	Query stores

  Command line:
		Database directory
		Cache directory
=end

require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require "selenium-webdriver"

class Stores
	def initialize( dir, cache, max)
		@dir          = dir
		@cache        = cache
		@max_matches  = max
		@scan         = File.open( @dir + '/scan.txt', 'a')
		@id           = 100000
		@driver       = nil
		@log          = File.open( @cache + '/scan.log', 'w')
		@errors       = 0
	end

	def accept_all( name, url)
		true
	end

	def accept_ios( name, url)
		if m = /\/id(\d+)($|\?)/.match( url)
			begin
				found, compatible, html = get_ios_compatibility( url, m[1])

				unless found
					found, compatible, html = get_ios_compatibility( url, m[1], false)
				end

				unless found
					error( "Compatibility section not found on #{url} for #{name}")
					File.open( @cache + '/ios_compatibility_not_found.html', 'w') do |io|
						io.puts html
					end
				end

				compatible
			rescue Exception => bang
				raise bang
				error( "Error getting page for #{name}: #{url}")
				false
			end
  	else
			error( "Unexpected URL for #{name}: #{url}")
	  	false
		end
	end

	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome if @driver.nil?
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def contains_pagoda_name( candidate, seq)
		candidate_words = phrase_words( candidate)
		@pagoda_sequences[seq].each do |id|
			@games[id].each do |game_words|
				return true if (game_words - candidate_words).size == 0
			end
		end
		false
	end

	def count_matches( sequence)
		count = 0
		@steam_games.each do |game|
			count += 1 if game['name'].index( sequence)
		end
		count
	end

	def error( msg)
		puts "*** #{msg}"
		@errors += 1
	end

	def flush
		@scan.flush
	end

	def get_ios_compatibility( url, id, reuse=true)
		path = "#{@cache}/ios_pages/#{id}.html"

		unless File.exist?( path) && reuse
			html = http_get( url)
			sleep 10
			html.force_encoding( 'UTF-8')
			html.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			File.open( path, 'w') {|io| io.print html}
		else
			html = IO.read( path)
		end

		compatible, found = false, false
		html.gsub( /data-test-bidi>.*?<\/p/m) do |text|
			found = true
			compatible = true if /(iOS|iPadOS)/i =~ text
		end

		return found, compatible, html
	end

	def gog
		path = @cache + '/gog.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - 20 * 24 * 60 * 60))
			loop, page, urls = true, 0, {}

			while (page < 200) && loop
				page += 1
				old_size = urls.size
				raw = browser_get "https://www.gog.com/games?page=#{page}&sort=release_asc"

				raw.split( ' ng-href="').each do |line|
					if m = /^(\/game[^"]*)">[^>]*>([^<]*)</.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls[text] = 'https://www.gog.com' + m[1]
					end
				end

				loop = (urls.size != old_size)
			end

			raise "Too many GOG pages" if loop
			File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => urls})}
		end

		JSON.parse( IO.read( path))['urls']
	end

	def http_get( url)
		uri = URI.parse( url)
		http = Net::HTTP.new( uri.host, uri.port)
		if /^https/ =~ url
			http.use_ssl     = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end

		response = http.request( Net::HTTP::Get.new(uri.request_uri))
		response.value
		response.body
	end

	def ios
		urls, letters = {}, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ*'
		purge_files( @cache + '/ios_pages', 200, 100)

		{'adventure':7002, 'puzzle':7012,'role-playing':7014}.each do |section, id|
			(0...letters.size).each do |i|
				path = @cache + "/ios-#{section}#{i+1}.json"
				if File.exist?( path) && (File.mtime( path) > (Time.now - 20 * 24 * 60 * 60))
					JSON.parse( IO.read( path))['urls'].each_pair {|k,v| urls[k] = v}
					next
				end

				puts "... Scanning IOS #{section} apps letter #{letters[i..i]}"
				page, loop, letter_urls = 0, true, {}
				while loop && (page < 200)
					page += 1
					old_size = letter_urls.size
					raw = http_get( "https://apps.apple.com/us/genre/ios-games-#{section}/id#{id}?letter=#{letters[i..i]}&page=#{page}")
					sleep 15
					raw.split( '<li>').each do |line|
						if m = /<a href="(https:\/\/apps.apple.com\/us\/app\/[^"]*)">([^>]*)</.match(line)
							text = m[2]
							text.force_encoding( 'UTF-8')
							text.encode!( 'US-ASCII',
														:invalid => :replace, :undef => :replace, :universal_newline => true)
							letter_urls[text] = m[1]
							urls[text] = m[1]
						end
					end
					loop = (old_size < letter_urls.size)
				end

				raise "Too many IOS games" if loop
				File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => letter_urls})}
			end
		end
		# https://apps.apple.com/us/genre/ios-games/id6014?letter=A

		urls
	end

	def load_pagoda
		@games = Hash.new {|h,k| h[k] = []}
		@pagoda_sequences = Hash.new {|h,k| h[k] = []}

		['alias.txt','game.txt'].each do |file|
			IO.readlines( @dir + '/' + file)[1..-1].each do |line|
				els = line.split( "\t")
				@games[els[0]] << phrase_words( els[1])
				sequences( els[1]) do |seq|
					@pagoda_sequences[seq] << els[0]
				end
			end
		end

		@pagoda_sequences.each_value do |list|
			list.uniq!
		end
	end

	def load_store_sequences( urls)
		@sequences = {}
		@pagoda_sequences.each_pair do |k,v|
			@sequences[k] = 0 if v.size <= @max_matches
		end

		urls.each_key do |name|
			sequences( name) do |seq|
				#puts "DEBUG200: #{name}" if seq == 'do'
				if ! @sequences[seq].nil?
					@sequences[seq] += 1
				end
			end
		end
	end

	def match_store_games( store, urls, acceptor)
		urls.each_pair do |name, url|
			next if not_a_game( name)

			matched = false
			sequences( name) do |seq|
				# if seq == 'do'
				# 	p [name, seq, @sequences[seq]]
				# end
				if (! matched) && (! @sequences[seq].nil?) && (@sequences[seq] <= @max_matches)
					if contains_pagoda_name( name, seq)
						matched = true
						if send( acceptor, name, url)
							write_match( store, name, url, seq)
						end
					end
				end
			end
		end
	end

	def not_a_game( name)
		phrase_words( name).each do |word|
			return true if @not_game_words[word]
		end
		false
	end

	def phrase_words( phrase)
		phrase.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
	end

	def purge_files( dir, keep_days, max_purge)
		to_delete, before = [], Time.now - keep_days * 24 * 60 * 60
		Dir.entries( dir).each do |f|
			next if /^\./ =~ f
			to_delete << f if File.mtime( dir + '/' + f) < before
		end
		to_delete = to_delete[0..max_purge] if to_delete.size > max_purge
		to_delete.each do |f|
			File.delete( dir + '/' + f)
		end
	end

	def reduce_word_sequences
		@sequences, old = {}, @sequences
		old.each_pair do |seq, count|
			@sequences[seq] = 0 if count <= @max_matches
		end
	end

	def report
		puts "*** #{@errors} errors" if @errors > 0
	end

	def sequences( phrase)
		words = phrase_words( phrase)
		words.each_index do |i|
			yield words[i]
			if (i + 1) < words.size
				yield( words[i] + ' ' + words[i+1])
			end
			if (i + 2) < words.size
				yield( words[i] + ' ' + words[i+1] + ' ' + words[i+2])
			end
		end
	end

	def set_not_game_words( *suspect)
		@not_game_words = Hash.new {|h,k| h[k] = false}
		suspect.each {|word| @not_game_words[word.downcase] = true}
		@games.each_value do |words|
			words.each {|word| @not_game_words[word] = false}
		end
	end

	def steam
		path = @cache + '/steam.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - 20 * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end
		end
		raw = JSON.parse( IO.read( path))['applist']['apps']
		urls = {}
		raw.each do |record|
			text = record['name']
			text.force_encoding( 'UTF-8')
			text.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			urls[text] = "https://store.steampowered.com/app/#{record['appid']}"
		end
		urls
	end

	def stores
		yield 'iOS',   ios,		:accept_ios
		yield 'GOG',   gog,		:accept_all
		yield 'Steam', steam,	:accept_all
	end

	def write_match( store, game, url, sequence)
		@id += 1
		@scan.puts "#{@id}\t#{store}\tStore\t#{game}\t#{game}\t#{url}"
		@log.puts "Store: #{store} Game: #{game} Sequence: #{sequence}"
	end
end

stores = Stores.new( ARGV[0], ARGV[1], ARGV[2].to_i)
stores.load_pagoda
stores.set_not_game_words( 'demo', 'OST', 'soundtrack', 'trailer')

stores.stores do |name, urls, acceptor|
	stores.load_store_sequences( urls)
	stores.reduce_word_sequences
	stores.match_store_games( name, urls, acceptor)
	stores.flush
end
stores.report