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
		@pagoda          = Pagoda.new( dir, cache)
		@suggested       = []
		@suggested_links = {}
		if File.exist?( dir + '/scan_stats.yaml')
			@scan_stats = YAML.load( IO.read( @dir + '/scan_stats.yaml'))
		else
			@scan_stats = {}
		end
		set_not_game_words
	end

	def add_bind(url, game_id)
		@pagoda.start_transaction
		@pagoda.delete( 'bind', :url, url)
		@pagoda.insert('bind', {url:url, id:game_id})
		@pagoda.end_transaction
	end

	def add_link( title, url, site=@site, type=@type)
		url = @pagoda.get_site_handler( site).coerce_url( url.strip)
		@suggested_links[url] = true

		if @pagoda.has?( 'link', :url, url)
			0
		else
			@pagoda.add_link( site, type, title, url)
			1
		end
	end

	def add_or_replace_link( title, url, site=@site, type=@type)
		url = @pagoda.get_site_handler( site).coerce_url( url.strip)
		@suggested_links[url] = true

		if @pagoda.has?( 'link', :url, url)
			@pagoda.delete_link(url)
		end

		@pagoda.add_link( site, type, title, url)
		1
	end

	def add_suggested
		site_suggests = Hash.new {|h,k| h[k] = 0}
		site_adds     = Hash.new {|h,k| h[k] = 0}
		site_dups     = Hash.new {|h,k| h[k] = 0}
		site_nones    = Hash.new {|h,k| h[k] = 0}
		limit         = @pagoda.settings['suggested_limit']
		list          = []

		@suggested.each do |link|
			debug_hook( 'reduce_suggested', link[:title], link[:url])
			site_suggests[ link[:site]] += 1
			if @pagoda.has?( 'link', :url, link[:url])
				site_dups[ link[:site]] += 1
			else
				freq = lowest_frequency( link[:title])
				list << [freq, link]
			end
		end

		list = list.shuffle.sort_by {|entry| entry[0]}

		list.each do |entry|
			link = entry[1]
			if not_a_game( link[:title])
				site_nones[ link[:site]] += 1
				next
			end
			debug_hook( 'match_games3', link[:title], link[:url])
			limit -= 1
			@pagoda.add_link( link[:site], link[:type], link[:title], link[:url])
			site_adds[ link[:site]] += 1
			break if limit <= 0
		end

		{'Suggested'     => site_suggests,
		 'Added'         => site_adds,
		 'Already added' => site_dups,
		 'Not a game'    => site_nones}.each_pair do |k,stats|
			stats.each do |site, count|
				puts "... #{site}: #{count} #{k}"
			end
		end
	end

	def bind(url,game_id)
		@pagoda.start_transaction
		@pagoda.insert( 'bind', {:url => url, :id => game_id})
		@pagoda.end_transaction
	end

	def correlate_site( url)
		return * @pagoda.correlate_site( url)
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

	def full( site, type, section='full')
		found = false

		@pagoda.settings[section].each do |scan|
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

	def get_links
		get_links_for(@site,@type) do |link|
			yield link.title, link.url
		end
	end

	def get_links_for(site,type)
		@pagoda.links do |link|
			(link.site == site) && (link.type == type)
		end.each do |link|
			yield link
		end
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

	def incremental( site, type, section='incremental')
		found = false
    load_old_redirects( @cache + '/redirects.yaml')

		@pagoda.settings[section].each do |scan|
			@site = scan['site']
			@type = scan['type']
			next unless (site == @site) || (site == 'All')
			next unless (type == @type) || (type == 'All')
			found = true

			puts "*** Incremental scan for site: #{@site} type: #{@type}"
			start = Time.now.to_i
			begin
				added = @pagoda.get_site_handler( @site).send( scan['method'].to_sym, self)
				puts "... #{added} links added" if added > 0
				puts "... Time taken #{Time.now.to_i - start} seconds"
				STDOUT.flush
			rescue Exception => bang
				error( "Site: " + @site + ": " + bang.message)
				raise unless site == 'All'
			end
		end

		unless found
			error( "No incremental scan for #{site}/#{type}")
			return
    end

    save_new_redirects( @cache + '/redirects.yaml')
	end

	def links_for_site( site)
		@pagoda.links do |link|
			yield link if link.site == site
		end
	end

	def link_page_anchors( site)
		links_for_site( site) do |link|
			next unless link.valid? && link.bound? && link.collation
			page = read_cached_page link
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

	def purge_lost_urls
		@pagoda.links do |link|
			if (link.site == @site) && (link.type == @type)
				unless @suggested_links[link.url]
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

	def read_cached_page(link)
		page = @pagoda.cache_read( link.timestamp)
		if page == ''
			puts "*** Link file missing: #{link.url}"
		end
		page
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

		@pagoda.settings['not_game_words'].each do |word|
			@not_game_words[word.downcase] = true
		end

		@pagoda.games.each do |game|
			phrase_words( game.name).each do |word|
				@not_game_words[word] = false
			end
		end
	end

	def suggest_link( title, url)
		url = @pagoda.get_site_handler( @site).coerce_url( url.strip)
		@suggested << {:site => @site, :type => @type, :title => title, :url => url, :orig_title => title}
		@suggested_links[url] = true
	end

	def test_full( site, type)
		full( site, type, 'test_full')
	end

	def test_incremental( site, type)
		incremental( site, type, 'test_incremental')
	end

	# def update_link(link, rec, body, ext, debug=false)
	# 	@pagoda.update_link(link, rec, body, ext, debug)
	# end

	# def update_new_link( url, site, type, title, new_url)
	# 	@pagoda.update_new_link(url, site, type, title, new_url)
	# end

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