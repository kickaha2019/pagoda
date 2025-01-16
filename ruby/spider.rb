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
require_relative 'pagoda'

class Spider
	include Common
	attr_reader :cache

	def initialize( pagoda, cache)
		@cache           = cache
		@errors          = 0
		@pagoda          = pagoda
		@suggested       = []
		@suggested_links = {}
		set_not_game_words

		@old_suggested_links = Hash.new {|h,k| h[k] = Hash.new {|h1,k1| h1[k1] = Hash.new {|h2,k2| h2[k2] = []}}}
		@pagoda.select('suggest') do |rec|
			@old_suggested_links[rec[:site]][rec[:type]][rec[:group]] << rec
		end
	end

	def add_bind(url, game_id)
		@pagoda.start_transaction
		@pagoda.update( 'bind', :url, url, {url:url, id:game_id})
		@pagoda.end_transaction
	end

	def add_link( title, url, site=@site, type=@type)
		url = @pagoda.get_site_handler( site).coerce_url( url.strip)
		#@suggested_links[url] = true

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

	def already_suggested
		@old_suggested_links[@site][@type].each_value do |list|
			list.each {|record| yield record}
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

		#add_suggested
	end

	def game_title(id)
		if g = @pagoda.game(id)
			g.name
		else
			'Unknown'
		end
	end

	def get_game(id)
		@pagoda.game(id)
	end

	def get_link(url)
		@pagoda.link(url)
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

	def has_suggests?(group)
		! @old_suggested_links[@site][@type][group].empty?
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

			puts "*** Scan for #{@site} / #{@type} / #{scan['method']}"
			start = Time.now.to_i
			begin
				@pagoda.get_site_handler( @site).send( scan['method'].to_sym, self)
				puts "... Time taken #{Time.now.to_i - start} seconds"
				STDOUT.flush
			rescue Exception => bang
				error( "Site: " + @site + ": " + bang.message)
				raise #unless site == 'All'
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

	def not_a_game( name)
		phrase_words( name).each do |word|
			return true if @not_game_words[word]
		end
		false
	end

	def phrase_words( phrase)
		phrase.to_s.gsub( /[\.;:'"\/\-=\+\*\(\)\?]/, '').downcase.split( ' ')
	end

	def purge_lost_urls
		@pagoda.links do |link|
			next if link.collation
			if (link.site == @site) && (link.type == @type)
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

	def refresh( group='All')
		to_delete, last_run = [], 0
		@pagoda.select('history') do |rec|
			if rec[:timestamp] < (@pagoda.now.to_i - 365 * 24 * 60 * 60)
				to_delete << rec[:timestamp]
			end

			if (rec[:site] == @site) && (rec[:type] == @type) && (rec[:group] == group.to_s)
				last_run = rec[:timestamp]
			end
		end

		unless to_delete.empty?
			@pagoda.start_transaction
			to_delete.each do |timestamp|
				@pagoda.delete('history',:timestamp, timestamp)
			end
			@pagoda.end_transaction
		end

		if last_run < (@pagoda.now.to_i - 12 * 60 * 60)
			count_links    = @pagoda.count('link')
			count_suggests = @pagoda.count('suggest')

			yield

			if count_links < @pagoda.count('link')
				puts "... #{@pagoda.count('link') - count_links} links added"
			end

			if count_suggests < @pagoda.count('suggest')
				puts "... #{@pagoda.count('suggest') - count_suggests} suggests added"
			end

			@pagoda.start_transaction
			@old_suggested_links[@site][@type][group].each do |rec|
				unless @suggested_links[rec[:url]]
					@pagoda.delete('suggest',:url, rec[:url])
				end
			end

			@pagoda.delete('history',:timestamp, last_run) if last_run > 0
			@pagoda.insert('history',
										 {site:@site, type:@type, group:group.to_s, timestamp:@pagoda.now.to_i})
			@pagoda.end_transaction
		end
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

	def settings
		@pagoda.settings
	end

	def suggest_link( group, title, url)
		url = @pagoda.get_site_handler( @site).coerce_url( url.strip)
		#return if @pagoda.has?('link',:url, url)
		@suggested_links[url] = true
		if @pagoda.has?('suggest',:url, url)
			false
		else
			@pagoda.start_transaction
			@pagoda.insert('suggest',
										 {site:@site, type:@type, title:title, url:url, group:group.to_s})
			@pagoda.end_transaction
			true
		end
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

	def yday
		@pagoda.now.yday
	end
end
