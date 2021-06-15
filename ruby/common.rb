require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require "selenium-webdriver"
require_relative 'pagoda'

module Common
	@@throttling    = Hash.new {|h,k| h[k] = 0}
	@@site_classes  = {}
	@@old_redirects = {}
	@@new_redirects = {}

	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome unless defined?( @driver)
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def get_site_class( name)
		name = 'IOS' if name == 'iOS'
		unless @@site_classes[name]
			require_relative "sites/#{name.gsub( ' ', '_').downcase}"
			@@site_classes[name] = Kernel.const_get( name.gsub( ' ', ''))
		end
		@@site_classes[name]
	end

	def html_links( url)
		page = http_get( url)
		page.force_encoding( 'UTF-8')
		page.encode!( 'US-ASCII',
									:invalid => :replace, :undef => :replace, :universal_newline => true)
		added = 0

		page.gsub( /http(s|):\/\/[0-9a-z\/\.\-_]*/mi) do |found|
			added += (yield found)
		end
		added
	end

	def http_get( url, delay = 10, headers = {})
		response = http_get_response( url, delay, headers)
  	response.value
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

	def http_redirect( url, depth = 0)
		return url if /\.(jpg|jpeg|png|gif)$/i =~ url

		if old = @@old_redirects[url]
			@@new_redirects[url] = old
			return old
		end

		response = http_get_response( url, 1)

		if (depth < 4) &&
				response.is_a?( Net::HTTPRedirection) &&
				(/^http(s|):/ =~ response['Location'])
			url1 = http_redirect( response['Location'], depth+1)
		else
			url1 = url
		end

		@@new_redirects[url] = url1
		url
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

	def throttle( url, delay)
		if m = /\/\/([^\/]*)\//.match( url)
			t = Time.now.to_i
			if t < delay + @@throttling[m[1]]
				sleep delay
			end
			@@throttling[m[1]] = t
		else
			raise "Strange URL"
		end
	end

	def to_filename( clazz)
		while m = /^(.*[a-z0-9])([A-Z])(.*)$/.match( clazz)
			clazz = m[1] + '_' + m[2].downcase + m[3]
		end
		clazz.downcase
	end

	def twitter_feed_links( account)
		page = http_get( "https://api.twitter.com/2/users/by?usernames=#{account}",
										 10,
										 {'Authorization' => "Bearer #{@settings['Twitter']['BEARER_TOKEN']}"})
		info = JSON.parse( page)
		id = info['data'][0]['id']

		page = http_get( "https://api.twitter.com/2/users/#{id}/tweets?max_results=100&exclude=retweets&tweet.fields=text,created_at",
										 10,
										 {'Authorization' => "Bearer #{@settings['Twitter']['BEARER_TOKEN']}"})
		page.force_encoding( 'UTF-8')
		page.encode!( 'US-ASCII',
									:invalid => :replace, :undef => :replace, :universal_newline => true)
		info = JSON.parse( page)

		oldest = '9999-12-31'
		added  = 0

		info['data'].each do |tweet|
			created = tweet['created_at'][0..9]
			oldest = created if created < oldest
			tweet['text'].gsub( /http(s|):\/\/[0-9a-z\/\.\-_]*/mi) do |found|
				begin
  				added += (yield http_redirect( found))
				rescue SocketError
					puts "!!! Socket error: #{found}"
				end
			end
		end

		puts "... Oldest tweet found for #{account} on #{oldest}"
		added
	end
end
