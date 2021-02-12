require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require "selenium-webdriver"
require_relative 'pagoda'

module Common
	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome unless defined?( @driver)
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def http_get( url, delay = 10)
		sleep delay
		uri = URI.parse( url)
		http = Net::HTTP.new( uri.host, uri.port)
		if /^https/ =~ url
			http.use_ssl     = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end

		response = http.request( Net::HTTP::Get.new(uri.request_uri))
		response.value
		response.body
	end

	def to_filename( clazz)
		while m = /^(.*[a-z0-9])([A-Z])(.*)$/.match( clazz)
			clazz = m[1] + '_' + m[2].downcase + m[3]
		end
		clazz.downcase
	end
end
