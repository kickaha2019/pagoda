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

	class Scan
		attr_reader :every

		def initialize(pagoda,defn)
			@site       = defn['site']
			@type       = defn['type']
			@method     = defn['method']
			@every      = defn['every'] ? defn['every'].to_i : 1
			@timestamps = []
			@state      = nil

			forgotten, timestamps, year_ago = [], [], Time.now.to_i - 365 * 24 * 60 * 60
			pagoda.select('history') do |rec|
				if rec[:timestamp] < year_ago
					forgotten << rec
					next
				end

				if (rec[:site] == @site) && (rec[:type] == @type) && (rec[:method] == @method)
					@timestamps << rec[:timestamp]
				end
			end

			pagoda.start_transaction
			forgotten.each do |timestamp|
				pagoda.delete('history',:timestamp,timestamp)
			end
			pagoda.end_transaction

			if @timestamps.empty?
				@timestamps = [0]
			else
				@timestamps.sort!.reverse!
				rec    = pagoda.get('history', :timestamp, @timestamps[0])[0]
				@state = rec[:state]
			end
		end

		def cost_per_day
			(@every > 1) ? (1.0 / @every) : 0
		end

		def overdue
			return 1 if @every < 1
			((Time.now.to_i - @timestamps[0] + (60 * 60 * 12)) / (60 * 60 * 24)) - (@every - 1)
		end

		def run(scanner,pagoda)
			puts "*** Run for #{@site} / #{@type} / #{@method}"
			scanner.set_site_type(@site, @type)

			start = Time.now.to_i
			begin
				count_links    = pagoda.count('link')
				count_suggests = pagoda.count('suggest')
				new_state = pagoda.get_site_handler( @site).send( @method.to_sym, scanner, @state)

				if new_state.is_a?( Integer) || new_state.is_a?( String)
					new_state = new_state.to_s
				else
					new_state = nil
				end

				found_links = pagoda.count('link') - count_links
				if found_links > 0
					puts "... #{found_links} links added"
				end

				found_suggests = pagoda.count('suggest') - count_suggests
				if found_suggests > 0
					puts "... #{found_suggests} suggests added"
				end

				pagoda.start_transaction
				(@timestamps[9..-1] || []).each do |timestamp|
					pagoda.delete('history',:timestamp,timestamp)
				end
				now = Time.now.to_i

				while pagoda.has?('history',:timestamp,now) do
					sleep 1
					now += 1
				end

				pagoda.insert('history',
											 {site:@site,
												type:@type,
												method:@method,
												timestamp:now,
												state:new_state,
												elapsed:(now - start),
												found:found_links+found_suggests})
				pagoda.end_transaction
				puts "... Time taken #{now - start} seconds"
				STDOUT.flush
			rescue Exception => bang
				scanner.error( "Site: " + @site + ": " + bang.message)
				raise #unless site == 'All'
			end
		end
	end

	def initialize( pagoda)
		@errors          = 0
		@pagoda          = pagoda
		@suggested       = []
		@suggested_links = {}
		set_not_game_words

		@old_suggested_links = Hash.new {|h,k| h[k] = Hash.new {|h1,k1| h1[k1] = []}}
		@pagoda.select('suggest') do |rec|
			@old_suggested_links[rec[:site]][rec[:type]] << rec
		end
	end

	def add_bind(url, game_id)
		@pagoda.start_transaction
		@pagoda.delete('bind', :url, url)
		@pagoda.insert('bind', {url:url, id:game_id})
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
		@old_suggested_links[@site][@type].each do |record|
			yield record
		end
	end

	def bind(url,game_id)
		@pagoda.start_transaction
		@pagoda.insert( 'bind', {:url => url, :id => game_id})
		@pagoda.end_transaction
	end

	def browser_driver
		@pagoda.close_database
		driver = super
		@pagoda.reopen_database
		driver
	end

	def correlate_site( url)
		return * @pagoda.correlate_site( url)
	end

	def debug_hook( site, name, url=nil)
		# if (/Alter Ego/i =~ name) || (/63110$/ =~ url)
		# 	puts "#{site}: #{name} #{url}"
		# end
	end

	def delete_suggest(url)
		@pagoda.start_transaction
		@pagoda.delete( 'suggest', :url, url)
		@pagoda.end_transaction
	end

	def directory
		@pagoda.directory
	end

	def error( msg)
		puts "*** #{msg}"
		@errors += 1
	end

	# def full( site, type, section='full')
	# 	found = false
	#
	# 	@pagoda.settings[section].each do |scan|
	# 		@site = scan['site']
	# 		@type = scan['type']
	# 		next unless (site == @site) || (site == 'All')
	# 		next unless (type == @type) || (type == 'All')
	# 		found = true
	#
	# 		puts "*** Full scan for site: #{@site} type: #{@type}"
	# 		before = @pagoda.count( 'link')
	# 		start = Time.now.to_i
	# 		@pagoda.get_site_handler( @site).send( scan['method'].to_sym, self)
	# 		added = @pagoda.count( 'link') - before
	# 		puts "... #{added} links added" if added > 0
	# 		puts "... Time taken #{Time.now.to_i - start} seconds"
	# 	end
	#
	# 	unless found
	# 		error( "No full scan for #{site}/#{type}")
	# 		return
	# 	end
	#
	# 	#add_suggested
	# end

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

	def report
		if @errors > 0
			puts "*** #{@errors} errors"
			exit 1
		end
	end

	def run( section)
		scans = @pagoda.settings[section].collect {|defn| Scan.new(@pagoda, defn)}

		# How many scans to run each time which are not every day?
		sum_cost_per_day = scans.inject(0) {|sum, scan| sum + scan.cost_per_day}
		to_run = sum_cost_per_day.to_i + 1

		# Sort scans by how overdue
		scans.sort_by! {|scan| [-scan.overdue,scan.every]}

		# Run as many scans as we can
		scans.each do |scan|
			next if scan.overdue < 1

			if scan.every < 2
				scan.run(self,@pagoda)
			else
				if to_run > 0
					scan.run(self,@pagoda)
					to_run -= 1
				end
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

	def set_site_type(site, type)
		@site = site
		@type = type
	end

	def settings
		@pagoda.settings
	end

	def suggest_link( title, url)
		url = @pagoda.get_site_handler( @site).coerce_url( url.strip)
		#return if @pagoda.has?('link',:url, url)
		@suggested_links[url] = true
		if @pagoda.has?('suggest',:url, url)
			false
		else
			@pagoda.start_transaction
			@pagoda.insert('suggest',
										 {site:@site,
											type:@type,
											title:title,
											reduced_title:Names.reduce(title),
											url:url})
			@pagoda.end_transaction
			true
		end
	end

	def wait_return
		puts "*** Press carriage return to continue"
		STDIN.gets
	end

	def wayback_link(url, archive)
		if (link = @pagoda.link(url)) && link.collation
			record = {
				site:link.site,
				type:link.type,
				title:link.title,
				url:archive,
				timestamp:Time.now.to_i,
				valid:true,
				static:true,
				reject:false,
				digest:link.digest
			}
			@pagoda.start_transaction
			@pagoda.insert('link',record)
			@pagoda.insert('bind',{url:archive,id:link.collation.id})
			@pagoda.delete('bind', :url, url)
			@pagoda.delete('link', :url, url)
			@pagoda.end_transaction
			true
		else
			false
		end
	end
end
