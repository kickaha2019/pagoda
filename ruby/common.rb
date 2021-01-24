require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require "selenium-webdriver"
require_relative 'pagoda'

module Common
	def browser_get( url)
		@driver = Selenium::WebDriver.for :chrome unless Kernel.defined?( @driver)
		@driver.navigate.to url
		sleep 15
		@driver.execute_script('return document.documentElement.outerHTML;')
	end

	def http_get( url)
		sleep 10
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
end
