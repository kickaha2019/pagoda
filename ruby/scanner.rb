=begin
	Query sites

  Command line:
		Database directory
		Cache directory
		Cache lifetime
		Max matches for each scan record to consider
		One or more sites to scan
=end

require_relative 'common'

class Scanner
	include Common
	attr_reader :cache

	def initialize( dir, cache)
		@dir          = dir
		@cache        = cache
		@scan         = File.open( @dir + '/scan.txt', 'a')
		@id           = 100000
		@errors       = 0
		@pagoda       = Pagoda.new( dir)
	end

	def accept_bound_expected( site, urls)
		unaccepted = {}

		urls.each_pair do |name, url|
			if @pagoda.has?( 'expect', :url, url) ||
				 @pagoda.has?( 'bind', :url, url)

				write_match( site, name, url, '')
			else
				unaccepted[name] = url
			end
		end

		unaccepted
	end

	def build_pagoda_frequencies
		frequencies = Hash.new {|h,k| h[k] = 0}

		@pagoda.games.each do |g|
			@pagoda.string_combos(g.name) do |combo, weight|
				frequencies[combo] += weight
			end
			g.aliases.each do |a|
				@pagoda.string_combos(a.name) do |combo, weight|
					frequencies[combo] += weight
				end
			end
		end

		frequencies
	end

	def build_scan_frequencies( urls)
		frequencies = Hash.new {|h,k| h[k] = 0}

		urls.keys.each do |key|
			@pagoda.string_combos( key) do |combo, weight|
				frequencies[combo] += weight
			end
		end

		frequencies
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

	def lowest_frequency( pagoda_freqs, scan_freqs, name)
		freq, match = 1000000, ''
		@pagoda.string_combos( name) do |combo, weight|
			if pagoda_freqs.include?(combo)
				if scan_freqs[combo] < freq
					freq  = scan_freqs[combo]
					match = combo
				end
			end
		end
		return freq, match
	end

	def match_games( pagoda_freqs, site, urls, limit)
		list       = []
		scan_freqs = build_scan_frequencies( urls)

		urls.each_pair do |name, url|
			if @pagoda.has?( 'expect', :url, url) ||
				 @pagoda.has?( 'bind', :url, url)

				if yield( name, url)
					write_match( site, name, url, '')
				end
			else
				freq, combo = lowest_frequency( pagoda_freqs, scan_freqs, name)
				list << [freq, name, url, combo]
			end
		end

		list.sort!

		list.each do |entry|
			name, url = entry[1], entry[2]
			next if (limit <= 0) || not_a_game( name)
			if yield( name, url)
				limit -= 1
				write_match( site, name, url, entry[3])
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
		phrase.to_s.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
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

		suspect.each do |word|
			@not_game_words[word.downcase] = true
		end

		@pagoda.games.each do |game|
			phrase_words( game.name).each do |word|
				@not_game_words[word] = false
		  end
		end
	end

	def write_match( site, game, url, join)
		@id += 1
		@scan.puts "#{@id}\t#{site.title}\t#{site.type}\t#{game}\t#{game}\t#{url}\t#{join}"
	end
end

scanner = Scanner.new( ARGV[0], ARGV[1])
scanner.set_not_game_words( 'demo', 'OST', 'soundtrack', 'trailer')
pagoda_freqs = scanner.build_pagoda_frequencies

ARGV[4..-1].each do |site_name|
  require_relative site_name.downcase
  site = Kernel.const_get( site_name).new
	urls = site.urls( scanner, ARGV[2].to_i)
	scanner.match_games( pagoda_freqs, site, urls, ARGV[3].to_i) do |game_name, game_url|
    site.accept( scanner, game_name, game_url)
	end
	scanner.flush
end

scanner.report