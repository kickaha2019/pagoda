require 'json'
require 'net/http'
require 'net/https'
require 'rack/utils'
require 'uri'
require "selenium-webdriver"

require_relative 'pagoda'
require_relative 'sites/default_site'

module Common
	@@throttling    = Hash.new {|h,k| h[k] = 0}
	@@old_redirects = {}
	@@new_redirects = {}

	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome unless defined?( @driver)
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def complete_url( base, url)
		return url if /^http(s|):/ =~ url
		raise "Unable to complete #{url} for #{base}" unless /^\// =~ url
		if m = /^([^:]*:\/\/[^\/]*)\//.match( base)
			return m[1] + url
		end
		raise "Unable to complete #{url} for #{base}"
	end

	def h(text)
		return '' if text.nil?
		Rack::Utils.escape_html(text)
	end

	def html_links( url, delay=10)
		throttle( url, delay)
		page = http_get( url)
		page.force_encoding( 'UTF-8')
		page.encode!( 'US-ASCII',
									:invalid => :replace, :undef => :replace, :universal_newline => true)
		added = 0

		page.scan( /href\s*=\s*"([^"]*)"/mi) do |found|
			added += (yield found[0].strip)
		end
		# page.gsub( /"http(s|):\/\/[^"]*"/mi) do |found|
		# 	added += (yield found[1..-2])
		# end
		added
	end

	def http_get( url, delay = 10, headers = {})
		response = http_get_response( url, delay, headers)
		begin
			response.value
		rescue
			puts "*** Problem URL: #{url}"
			raise
		end
		response.body
	end

	def http_get_cached( cache_dir, url, lifespan)
		cache_file = cache_dir + '/' + url.gsub( /[\/:]/, '_')
		if File.exist?( cache_file) &&
			 ((File.mtime( cache_file) + lifespan) >= Time.now)
			return IO.read( cache_file), cache_file
		else
			text = http_get( url)
			File.open( cache_file, 'w') {|io| io.print text}
			return text, cache_file
		end
	end

	def http_get_response( url, delay = 10, headers = {})
		throttle( url, delay)
		uri = URI.parse( url)

		request = Net::HTTP::Get.new(uri.request_uri)
		request['Accept']          = 'text/html,application/xhtml+xml,application/xml'
		request['Accept-Language'] = 'en-gb'
		request['User-Agent']      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

		headers.each_pair do |k,v|
			request[k] = v
		end

		use_ssl     = uri.scheme == 'https'
		verify_mode = OpenSSL::SSL::VERIFY_NONE

		Net::HTTP.start( uri.hostname, uri.port, :use_ssl => use_ssl, :verify_mode => verify_mode) {|http|
			http.request( request)
		}
	end

	def http_redirect( url, depth = 0, debug = false)
		p ['http_redirect', url, depth] if debug
		return url if /\.(jpg|jpeg|png|gif)$/i =~ url

		if url1 = @@old_redirects[url]
			p ['http_redirect: cached', url, depth, url1] if debug
		else
			response = http_get_response( url, 1)

			if (depth < 4) &&
					response.is_a?( Net::HTTPRedirection) &&
					(/^http(s|):/ =~ response['Location'])
				url1 = http_redirect( response['Location'], depth+1, debug)
			else
				url1 = url
			end
		end

		@@new_redirects[url] = url1
		url1
	end

	def load_old_redirects( path)
		if File.exist?( path)
			@@old_redirects = YAML.load( IO.read( path))
		end
	end

	def save_new_redirects( path)
		File.open( path, 'w') do |io|
			io.print @@new_redirects.to_yaml
		end
	end

	def throttle( url, delay=10)
		if m = /\/\/([^\/]*)(\/|$)/.match( url)
			t = Time.now.to_i
			if t < delay + @@throttling[m[1]]
				sleep delay
			end
			@@throttling[m[1]] = t
		else
			raise "Strange URL: #{url}"
		end
	end

	def to_filename( clazz)
		while m = /^(.*[a-z0-9])([A-Z])(.*)$/.match( clazz)
			clazz = m[1] + '_' + m[2].downcase + m[3]
		end
		clazz.downcase
	end

	def twitter_feed_links( account, days=75)
		page = http_get( "https://api.twitter.com/2/users/by?usernames=#{account}",
										 10,
										 {'Authorization' => "Bearer #{@settings['Twitter']['BEARER_TOKEN']}"})
		info = JSON.parse( page)
		id = info['data'][0]['id']

		oldest    = '9999-12-31'
		months2   = (Time.now - days * 24 * 60 * 60).strftime( "%Y-%m-%d")
		oldest_id = nil
		added     = 0

		begin
			while oldest > months2
				a, oldest, oldest_id = twitter_feed_links1( id, oldest_id) do |text, found|
					yield text, found
				end
				added += a
			end
		rescue
		end

		puts "... Oldest tweet found for #{account} on #{oldest}"
		added
	end

	def twitter_feed_links1( account_id, until_id)
		before = until_id ? "&until_id=#{until_id}" : ''
		puts "... Finding tweets for #{account_id} up to #{until_id}"
		page = http_get( "https://api.twitter.com/2/users/#{account_id}/tweets?max_results=100#{before}&exclude=retweets&tweet.fields=text,created_at,id",
										 10,
										 {'Authorization' => "Bearer #{@settings['Twitter']['BEARER_TOKEN']}"})
		page.force_encoding( 'UTF-8')
		page.encode!( 'US-ASCII',
									:invalid => :replace, :undef => :replace, :universal_newline => true)
		info = JSON.parse( page)

		oldest    = '0000-00-00'
		oldest_id = nil
		added     = 0

		info['data'].each do |tweet|
			if oldest_id.nil? || (oldest_id > tweet['id'])
				oldest    = tweet['created_at'][0..9]
				oldest_id = tweet['id']
			end

			tweet['text'].gsub( /http(s|):\/\/[0-9a-z\/\.\-_]*/mi) do |found|
				begin
					#debug = (/Root Letter/ =~ tweet['text'])
					added += (yield tweet['text'], http_redirect( found))
				rescue SocketError
					puts "!!! Socket error: #{found}"
				end
			end
		end

		oldest = '0000-00-00' unless oldest_id && (oldest_id != until_id)
		return added, oldest, oldest_id
	end
end
