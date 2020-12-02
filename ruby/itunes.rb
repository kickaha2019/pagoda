#!/bin/ruby
=begin
	Query iTunes store

	https://itunes.apple.com/search?entity=macSoftware&term=memoria&media=software&limit=1&country=GB
	
	https://itunes.apple.com/search?attribute=titleTerm&entity=allTrack&term=memoria&media=all&limit=10

	https://itunes.apple.com/search?entity=macSoftware&term=memoria&media=software&limit=1
=end

require 'json'
require 'net/https'

site = Net::HTTP.new( "itunes.apple.com",443)
site.use_ssl = true
#genres = ['Role Playing','Adventure','Puzzle']
#words = ARGV[1].split('+')

['us','gb'].each do |country|
	resp = site.get( "/search?entity=#{ARGV[0]}&term=#{ARGV[1]}&media=software&limit=1&country=#{country}")
	json = JSON.parse(resp.body)

	json["results"].each do |result|
#		interesting = false
#		result['genres'].each do |genre|
#			interesting = true if genres.include?( genre)
#		end
		
#		if interesting
#			nameWords = result['trackName'].downcase.split( ' ')
#			words.each {|word| interesting = false if not nameWords.include?( word)}
#		end
		
		#p result['genres']
#		next if not interesting
		puts "<A HREF=\"#{result['trackViewUrl']}\">#{result['trackName']}</A>"
		exit
	end
end

puts ' '