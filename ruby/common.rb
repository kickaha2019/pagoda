require 'json'
require 'net/http'
require 'net/https'
require 'rack/utils'
require 'uri'
require "selenium-webdriver"

module Common
	@@throttling    = Hash.new {|h,k| h[k] = 0}
	@@old_redirects = {}
	@@new_redirects = {}

	def browser_driver
		@@driver = Selenium::WebDriver.for :chrome unless defined?( @@driver)
		@@driver
	end

	def browser_get( url)
		driver = browser_driver
		driver.navigate.to url
		sleep 15
		driver.execute_script('return document.documentElement.outerHTML;')
	end

	def browser_close
		if defined?( @@driver)
			@@driver.quit
		end
	end

	def complete_url( base, url)
		return url if /^http(s|):/ =~ url
		raise "Unable to complete #{url} for #{base}" unless /^\// =~ url
		if m = /^([^:]*:\/\/[^\/]*)\//.match( base)
			return m[1] + url
		end
		raise "Unable to complete #{url} for #{base}"
	end

	def curl(url, delay=10)
		throttle( url, delay)
		if ! system( "curl -s -o /tmp/curl.out \"#{url}\"")
			raise 'Error running curl'
		end
		IO.read('/tmp/curl.out')
	end

	def e( text)
		CGI.escape( text)
	end

	def force_ascii(data)
		if data.is_a? String
			# Try converting odd characters
			begin
				data = data.gsub( '–', '-').gsub( '’', "'")
			rescue
			end

			# Force to US ASCII
			data.force_encoding( 'UTF-8')
			data.encode!( 'US-ASCII',
										:replace           => ' ',
										:invalid           => :replace,
										:undef             => :replace,
										:universal_newline => true)
		elsif data.is_a? Array
			[].tap do |array|
				data.each do |d|
					array << force_ascii(d)
				end
			end
		elsif data.is_a? Hash
			{}.tap do |map|
				data.each_pair do |k,v|
					map[k] = force_ascii(v)
				end
			end
		else
			data
		end
	end

	def h(text)
		return '' if text.nil?
		Rack::Utils.escape_html(text)
	end

	def html_anchors( url, delay=10, headers = {})
		page = http_get( url, delay, headers)
		return if page.nil?
		page.force_encoding( 'UTF-8')
		page.encode!( 'US-ASCII',
									:invalid => :replace, :undef => :replace, :universal_newline => true)

		Nodes.parse(page).css('a') do |a|
			yield( a['href'], a.text.strip)
		end

		0
	end

	def http_get( url, delay = 10, headers = {})
		response = http_get_response( url, delay, headers)
		if response.is_a?( Net::HTTPBadGateway) || response.is_a?( Net::HTTPGatewayTimeOut)
			sleep 60
			response = http_get_response( url, delay, headers)
		end
		begin
			response.value
		rescue
			puts "*** Problem URL: #{url}"
			raise
		end
		response.body
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

	def http_get_threaded( url)
		@http_get_threaded_url = url
		@http_get_threaded_got = nil

		Thread.new do
			begin
				response = http_get_response( url)
				if url == @http_get_threaded_url
					if response.is_a?( Net::HTTPNotFound)
						@http_get_threaded_got = [false, 'Not found']
					else
						@http_get_threaded_got = [true, response]
					end
				end
			rescue Exception => bang
				if url == @http_get_threaded_url
					@http_get_threaded_got = [false, bang.message]
				end
			end
		end

		(0...600).each do
			sleep 0.1
			unless @http_get_threaded_got.nil?
				return * @http_get_threaded_got
			end
		end

		sleep 300
		return false, "Timeout"
	end

	def http_post( url, delay = 10, headers = {}, body = nil)
		throttle( url, delay)
		uri = URI.parse( url)
		http = Net::HTTP.new(uri.hostname,uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(URI(url), headers)
		request.body = body if body
		http.request(request).body
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

	def redirected_url(old_location, new_location)
		if /^\// =~ new_location
			m = /^([^\/]*\/\/[^\/]*)($|\/)/.match(old_location)
			m[1] + new_location
		else
			new_location
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
