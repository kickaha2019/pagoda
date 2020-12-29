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

class Scanner
	attr_reader :cache

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

	def http_get( url)
		sleep 10
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

	def match_games( site, type, urls)
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
						if yield( name, url)
							write_match( site, type, name, url, seq)
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

	def write_match( site, type, game, url, sequence)
		@id += 1
		@scan.puts "#{@id}\t#{site}\t#{type}\t#{game}\t#{game}\t#{url}"
		@log.puts "Site: #{site} Game: #{game} Sequence: #{sequence}"
	end
end

scanner = Scanner.new( ARGV[0], ARGV[1], ARGV[2].to_i)
scanner.load_pagoda
scanner.set_not_game_words( 'demo', 'OST', 'soundtrack', 'trailer')

ARGV[3..-1].each do |site_name|
  require_relative site_name.downcase
  site = Kernel.const_get( site_name).new
	urls = site.urls( scanner)

	scanner.load_store_sequences( urls)
	scanner.reduce_word_sequences
	scanner.match_games( site.title, site.type, urls) {|game_name, game_url| site.accept( scanner, game_name, game_url)}
	scanner.flush
end

scanner.report