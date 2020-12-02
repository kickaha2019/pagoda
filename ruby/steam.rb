=begin
	Query Steam store

  Command line:
		Database directory
=end

require 'json'
require 'net/https'

class Steam
	def initialize( dir, max)
		@dir         = dir
		@max_matches = max
		@sequences   = Hash.new {|h,k| h[k] = 0}
		@scan        = File.open( @dir + '/scan.txt', 'a')
		@id          = 100000
	end

	def count_matches( sequence)
		count = 0
		@steam_games.each do |game|
			count += 1 if game['name'].index( sequence)
		end
		count
	end

	def flush
		@scan.flush
	end

	def load_steam_games
		path = @dir + '/steam.json'
		unless File.exist?( path) && (File.mtime( path) > (Time.now - 20 * 24 * 60 * 60))
			if ! system( "curl -o #{path} https://api.steampowered.com/ISteamApps/GetAppList/v2/")
				raise 'Error retrieving steam data'
			end
		end
		@steam_games = JSON.parse( IO.read( path))['applist']['apps']
	end

	def load_pagoda_sequences
		['alias.txt','game.txt'].each do |file|
		  IO.readlines( @dir + '/' + file)[1..-1].each do |line|
				sequences( line.split( "\t")[1]) do |seq|
					@sequences[seq] += 1
				end
			end
		end
	end

	def load_steam_sequences
		@steam_games.each do |game|
			sequences( game['name']) do |seq|
				if ! @sequences[seq].nil?
					@sequences[seq] += 1
				end
			end
		end
	end

	def match_steam_sequences
		@steam_games.each do |game|
			matched = false
			sequences( game['name']) do |seq|
				if (! matched) && (! @sequences[seq].nil?)
					matched = true
					write_match( game, seq)
				end
			end
		end
	end

	def sequences( phrase)
		words = phrase.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
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

	def reduce_word_sequences
		@sequences, old = {}, @sequences
		old.each_pair do |seq, count|
			@sequences[seq] = 0 if count <= @max_matches
		end
	end

	def write_match( game, sequence)
		@id += 1
		@scan.puts "#{@id}\tSteam\tStore\t#{game['name']}\t#{game['name']}\thttps://steamcommunity.com/app/#{game['appid']}"
	end
end

steam = Steam.new( ARGV[0], ARGV[1].to_i)
steam.load_steam_games
steam.load_pagoda_sequences
steam.reduce_word_sequences
steam.load_steam_sequences
steam.reduce_word_sequences
steam.match_steam_sequences
steam.flush