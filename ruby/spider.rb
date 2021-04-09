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

	def initialize( dir, cache)
		@dir      = dir
		@cache    = cache
		@errors   = 0
		@pagoda   = Pagoda.new( dir)
		@settings = YAML.load( IO.read( dir + '/settings.yaml'))
		@rebases  = Hash.new {|h,k| h[k] = {}}
		@scans    = Hash.new {|h,k| h[k] = {}}

		handle_rebase 'Adventure Gamers', 'Review' do
			verified_links do |url|
				if /^https:\/\/adventuregamers\.com\/.*\/articles\/view\//i =~ url
					unless /^\d+$/ =~ url.split('/')[-1]
						p [url]
						exit 1
					end
				end
			end
		end

		handle_scan 'Adventure Gamers', 'Review' do
			twitter_feed_links( 'adventuregamers') do |link|
				if /^https:\/\/adventuregamers.com\/articles\/view\/.*$/ =~ link
					add_link( '', link)
				end
			end
		end
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

		@scans.each_pair do |scan_site, types|
			next unless (site == scan_site) || (site == 'All')
			types.each_pair do |scan_type, handler|
				next unless (type == scan_type) || (type == 'All')
				found = true

				@site = scan_site
				@type = scan_type
				puts "*** Scanning #{@site} #{@type}"
				before = @pagoda.count( 'link')
				start = Time.now.to_i
				handler.call
				added = @pagoda.count( 'link') - before
				puts "... #{added} links added" if added > 0
				puts "... Time taken #{Time.now.to_i - start} seconds"
			end
		end

		unless found
			error( "No scan for #{site}/#{type}")
			return
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