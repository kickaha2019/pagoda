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

	def build_scan_frequencies
		frequencies = Hash.new {|h,k| h[k] = 0}

		@url2link.values.each do |title|
			@pagoda.string_combos( title) do |combo, weight|
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

	def debug_hook( site, name, url=nil)
		# if (/Alter Ego/i =~ name) || (/63110$/ =~ url)
		# 	puts "#{site}: #{name} #{url}"
		# end
	end

	def error( msg)
		puts "*** #{msg}"
		@errors += 1
	end

	def find_in_sites( lifetime)
		@url2link = {}
		(0..1000).each do |page|
			complete = true

			@sites.each do |site|
				next if site[:complete]

				old_count = @url2link.size
				site[:site].find( self, page, lifetime, @url2link)

				if old_count == @url2link.size && site[:site].complete?( self)
					site[:complete] = true
				else
					complete = false
				end
			end

			if complete
				break
			elsif page >= 500
				raise 'Too many pages scanned'
			end
		end
	end

	def flush
		@scan.flush
	end

	def load_sites
		@sites = []
		ARGV[4..-1].each do |site_name|
			puts "***** Loading #{site_name}"
			require_relative to_filename( 'sites/' + site_name)
			site = Kernel.const_get( site_name).new
			@sites << {name:site_name, site:site, complete:false}
		end
	end

	def load_snapshot( path)
		re = /^#{path.split('.')[0]}_(\d+)\.#{path.split('.')[1]}$/
		found = []

		Dir.entries( @dir).each do |f|
			if m = re.match( f)
				found << m[1].to_i
			end
		end

		if found.size > 1
			found.sort!
			IO.read( "#{@dir}/#{path.split('.')[0]}_#{found[-2]}.#{path.split('.')[1]}")
		elsif found.size > 0
			IO.read( "#{@dir}/#{path.split('.')[0]}_#{found[0]}.#{path.split('.')[1]}")
		else
			nil
		end
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

	def match_games( limit)
		list       = []
		pagoda_freqs = build_pagoda_frequencies
		scan_freqs   = build_scan_frequencies

		@url2link.each_pair do |url, link|
			debug_hook( 'match_games1', link[:title], url)
			unless @pagoda.has?( 'link', :url, url)
				freq, combo = lowest_frequency( pagoda_freqs, scan_freqs, link[:title])
				list << [freq, link, combo]
			end
		end

		list.sort_by! {|entry| entry[0]}

		list.each do |entry|
			link, combo = entry[1], entry[2]
			next if (limit <= 0) || not_a_game( link[:title])
			debug_hook( 'match_games3', link[:title], link[:url])
			limit -= 1
			write_match( link, combo)
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

	def save_snapshot( urls, path)
		re = /^#{path.split('.')[0]}_(\d+)\.#{path.split('.')[1]}$/
		found = []

		Dir.entries( @dir).each do |f|
			if m = re.match( f)
				found << m[1].to_i
			end
		end

		File.open( "#{@dir}/#{path.split('.')[0]}_#{found.size}.#{path.split('.')[1]}", 'w') do |io|
			io.print JSON.generate( urls)
		end

		found.each do |i|
			File.delete( "#{@dir}/#{path.split('.')[0]}_#{i}.#{path.split('.')[1]}")
		end
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

	def write_match( link, join)
		debug_hook( 'write_match1', link[:title], link[:url])
		@id += 1
		@scan.puts "#{@id}\t#{link[:site]}\t#{link[:type]}\t#{link[:title]}\t#{link[:title]}\t#{link[:url]}\t#{join}"
	end
end

scanner = Scanner.new( ARGV[0], ARGV[1])
scanner.set_not_game_words( 'demo', 'OST', 'soundtrack', 'trailer')
scanner.load_sites
scanner.find_in_sites( ARGV[2].to_i)
scanner.match_games( ARGV[3].to_i)
scanner.flush
scanner.report