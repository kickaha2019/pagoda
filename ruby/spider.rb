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
		@dir             = dir
		@cache           = cache
		@errors          = 0
		@pagoda          = Pagoda.new( dir)
		@settings        = YAML.load( IO.read( dir + '/settings.yaml'))
		@suggested       = []
		@suggested_links = {}
		if File.exist?( dir + '/scan_stats.yaml')
			@scan_stats = YAML.load( IO.read( @dir + '/scan_stats.yaml'))
		else
			@scan_stats = {}
		end
		set_not_game_words
	end

	def add_link( title, url)
		url = @pagoda.get_site_handler( @site).coerce_url( url)
		if @pagoda.has?( 'link', :url, url)
			0
		else
			@pagoda.add_link( @site, @type, title, url)
			1
		end
	end

	def add_suggested
		limit        = @settings['suggested_limit']
		list         = []

		@suggested.each do |link|
			debug_hook( 'reduce_suggested', link[:title], link[:url])
			unless @pagoda.has?( 'link', :url, link[:url])
				freq = lowest_frequency( link[:title])
				list << [freq, link]
			end
		end

		list.sort_by! {|entry| entry[0]}

		list.each do |entry|
			link = entry[1]
			next if (limit <= 0) || not_a_game( link[:title])
			debug_hook( 'match_games3', link[:title], link[:url])
			limit -= 1
			@pagoda.add_link( link[:site], link[:type], link[:title], link[:url])
		end
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
			@pagoda.get_site_handler( @site).send( scan['method'].to_sym, self)
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

	def get_scan_stats( site, section)
		return {} unless @scan_stats[site] && @scan_stats[site][section]
		@scan_stats[site][section]
	end

	def http_get_wrapped( url)
		response = http_get_response( url)
		if response.code == '404'
			return false, nil
		else
			begin
				return true, response.body
			rescue
				puts "*** #{url}"
				raise
			end
		end
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
			added = @pagoda.get_site_handler( @site).send( scan['method'].to_sym, self)
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

	def link_page_anchors( site)
		@pagoda.links do |link|
			next unless link.site == site
			next unless link.valid? && link.bound? && link.collation
			page = IO.read( @cache + "/verified/#{link.timestamp}.html")
			page.scan( /<a([^>]*)>([^<]*)</im) do |anchor|
				if m = /href\s*=\s*"([^"]*)"/i.match( anchor[0])
					next if /\.(jpg|jpeg|png|gif)$/i =~ m[1]
					yield link.collation.name, m[1], anchor[1]
				end
			end
		end
	end

	def lowest_frequency( name)
    @pagoda.rarity( name)
	end

	def not_a_game( name)
		phrase_words( name).each do |word|
			return true if @not_game_words[word]
		end
		false
	end

	def patch_orig_title( url, title)
		if link = @pagoda.link( url)
			link.patch_orig_title( title)
		end
	end

	def phrase_words( phrase)
		phrase.to_s.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
	end

	def purge_lost_urls( re)
		@pagoda.links do |link|
			if re =~ link.url
				unless @suggested_links[link.url] || link.collation
					puts "... Purging #{link.url}"
					link.delete
				end
			end
		end
	end

	def put_scan_stats( site, section, stats)
		if stats['count']
			if stats['max_count'].nil? || (stats['count'] > stats['max_count'])
				stats['max_count'] = stats['count']
				stats['max_date']  = Time.now.to_i
			end
		end
		@scan_stats[site] = {} unless @scan_stats[site]
		@scan_stats[site][section] = stats
		File.open( @dir + '/scan_stats.yaml', 'w') do |io|
			io.print @scan_stats.to_yaml
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
		url = @pagoda.get_site_handler( @site).coerce_url( url)
		@suggested << {:site => @site, :type => @type, :title => title, :url => url, :orig_title => title}
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