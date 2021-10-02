=begin
	Find links

  Command line:
		Database
		Cache
		Action
		Site
		Type
=end

require_relative 'common'

class Spider
	include Common
	attr_reader :cache

	def initialize( dir, cache)
		@dir       = dir
		@cache     = cache
		@errors    = 0
		@pagoda    = Pagoda.new( dir)
		@settings  = YAML.load( IO.read( dir + '/settings.yaml'))
		@suggested = []
		@suggested_links = {}
		set_not_game_words
	end

	def add_link( title, url)
		if @pagoda.has?( 'link', :url, url)
			0
		else
			@pagoda.start_transaction
			@pagoda.insert( 'link',
									    {:site => @site,
											:type      => @type,
											:title     => title,
											:url       => url,
											:timestamp => 1})
			@pagoda.end_transaction
			1
		end
	end

	def add_suggested
		limit        = @settings['suggested_limit']
		list         = []
		pagoda_freqs = build_pagoda_frequencies
		scan_freqs   = build_scan_frequencies

		@suggested.each do |link|
			debug_hook( 'reduce_suggested', link[:title], link[:url])
			unless @pagoda.has?( 'link', :url, link[:url])
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
			@pagoda.start_transaction
			@pagoda.insert( 'link',
											{:site => link[:site],
											 :type      => link[:type],
											 :title     => link[:title],
											 :url       => link[:url],
											 :timestamp => 1})
			@pagoda.end_transaction
		end
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

		@suggested.each do |suggest|
			@pagoda.string_combos( suggest[:title]) do |combo, weight|
				frequencies[combo] += weight
			end
		end

		frequencies
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

	def full( site, type)
		found = false

		@settings['full'].each do |scan|
			@site = scan['site']
			@type = scan['type']
			next unless (site == @site) || (site == 'All')
			next unless (type == @type) || (type == 'All')
			found = true

			puts "*** Full scan for site: #{@site} type: #{@type}"
			before = @pagoda.count( 'link')
			start = Time.now.to_i
			get_site_class( @site).new.send( scan['method'].to_sym, self)
			added = @pagoda.count( 'link') - before
			puts "... #{added} links added" if added > 0
			puts "... Time taken #{Time.now.to_i - start} seconds"
		end

		unless found
			error( "No full scan for #{site}/#{type}")
			return
		end

		add_suggested
	end

	def incremental( site, type)
		found = false
    load_old_redirects( @cache + '/redirects.yaml')

		@settings['incremental'].each do |scan|
			@site = scan['site']
			@type = scan['type']
			next unless (site == @site) || (site == 'All')
			next unless (type == @type) || (type == 'All')
			found = true

			puts "*** Incremental scan for site: #{@site} type: #{@type}"
			start = Time.now.to_i
			added = get_site_class( @site).new.send( scan['method'].to_sym, self)
			puts "... #{added} links added" if added > 0
			puts "... Time taken #{Time.now.to_i - start} seconds"
			STDOUT.flush
		end

		unless found
			error( "No incremental scan for #{site}/#{type}")
			return
    end

    save_new_redirects( @cache + '/redirects.yaml')
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

	def not_a_game( name)
		phrase_words( name).each do |word|
			return true if @not_game_words[word]
		end
		false
	end

	def phrase_words( phrase)
		phrase.to_s.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
	end

	def purge_lost_urls( re)
		@pagoda.links do |link|
			if re =~ link.url
				unless @suggested_links[link.url]
					puts "... Purging #{link.url}"
					link.delete
				end
			end
		end
	end

	def rebase( site, type)
		unless @rebases[site][type]
			error( "No rebase for #{site}/#{type}")
			return
		end

		puts "... Rebasing #{site}/#{type}"
		to_delete = []
		@pagoda.links do |link|
			if link.site == site && link.type == type
				to_delete << link
			end
		end
		to_delete.each {|link| link.delete}

		before = @pagoda.count( 'link')
		@rebases[site][type].call
		puts "... #{to_delete.size} deleted #{@pagoda.count( 'link') - before} added"
	end

	def report
		if @errors > 0
			puts "*** #{@errors} errors"
			exit 1
		end
	end

	def search( dir, max_searches)
		site_cache_dir = @cache + '/' + dir
		newest, time = 0, 0

		Dir.entries( site_cache_dir).each do |f|
			if m = /^(\d+\.json$)/.match( f)
				t = File.mtime( site_cache_dir + '/' + f).to_i
				if t > time
					newest, time = m[1].to_i, t
				end
			end
		end

		max_game_id, looped = 0, false
		@pagoda.games.each do |game|
			max_game_id = game.id if game.id > max_game_id
		end

		while max_searches > 0
			newest += 1

			if newest > max_game_id
				return if looped
				looped = true
				newest = 0
				next
			end

			unless @pagoda.has?( 'game', :id, newest)
				next
			end

			max_searches -= 1
			game = @pagoda.game( newest)
			urls = yield game.name

			game.aliases.each do |a|
				urls += yield a.name
			end

			File.open( "#{site_cache_dir}/#{newest}.json", 'w') do |io|
				io.puts urls.to_json
			end
		end
	end

	def set_not_game_words
		@not_game_words = Hash.new {|h,k| h[k] = false}

		@settings['not_game_words'].each do |word|
			@not_game_words[word.downcase] = true
		end

		@pagoda.games.each do |game|
			phrase_words( game.name).each do |word|
				@not_game_words[word] = false
			end
		end
	end

	def suggest_link( title, url)
		@suggested << {:site => @site, :type => @type, :title => title, :url => url}
		@suggested_links[url] = true
	end

	def verified_links
		Dir.entries( @cache + "/verified").each do |f|
			next unless /\.html$/ =~ f
			page = IO.read( @cache + "/verified/" + f)
			page.force_encoding( 'UTF-8')
			page.encode!( 'US-ASCII',
										:invalid => :replace, :undef => :replace, :universal_newline => true)
			page.gsub( /http(s|):[a-z0-9\.\/]*/) do |link|
				yield link
			end
		end
	end

	def wait_return
		puts "*** Press carriage return to continue"
		STDIN.gets
	end
end

spider = Spider.new( ARGV[0], ARGV[1])
spider.send( ARGV[2].to_sym, ARGV[3], ARGV[4])
spider.report