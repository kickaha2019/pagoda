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
		@dir      = dir
		@cache    = cache
		@errors   = 0
		@pagoda   = Pagoda.new( dir)
		@settings = YAML.load( IO.read( dir + '/settings.yaml'))
	end

	def add_link( title, url)
		unless @pagoda.has?( 'link', :url, url)
			@pagoda.start_transaction
			@pagoda.insert( 'link',
									    {:site => @site,
											:type      => @type,
											:title     => title,
											:url       => url,
											:timestamp => 1})
			@pagoda.end_transaction
		end
	end

	def error( msg)
		puts "*** #{msg}"
		@errors += 1
	end

	def handle_rebase( site, type, &block)
		@rebases[site][type] = block
	end

	def handle_scan( site, type, &block)
		@scans[site][type] = block
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

	def scan( site, type)
		found = false

		@settings['scan'].each do |scan|
			@site = scan['site']
			@type = scan['type']
			next unless (site == @site) || (site == 'All')
   		next unless (type == @type) || (type == 'All')
	  	found = true

			puts "*** Scanning #{@site} #{@type}"
			before = @pagoda.count( 'link')
			start = Time.now.to_i
			get_site_class( @site).new.send( scan['method'].to_sym, self)
			added = @pagoda.count( 'link') - before
			puts "... #{added} links added" if added > 0
			puts "... Time taken #{Time.now.to_i - start} seconds"
		end

		unless found
			error( "No scan for #{site}/#{type}")
			return
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