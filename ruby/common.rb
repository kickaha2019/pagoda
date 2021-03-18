require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require "selenium-webdriver"
require_relative 'pagoda'

module Common
	@@throttling  = Hash.new {|h,k| h[k] = 0}

	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome unless defined?( @driver)
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def http_get( url, delay = 10, headers = {})
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

		response = Net::HTTP.start( uri.hostname, uri.port, :use_ssl => use_ssl, :verify_mode => verify_mode) {|http|
			http.request( request)
		}

		response.value
		response.body
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
end
