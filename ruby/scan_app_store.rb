#!/bin/ruby
=begin
	Scan iTunes app stores for games
=end

require "rexml/document"

#
# Get latest list of game apps from the app store 
#
if not system( "curl http://itunes.apple.com/gb/rss/newapplications/limit=300/genre=6014/xml >#{ARGV[1]}")
    raise "Error accessing app store"
end

#
# First load existing list of games in the app store
#
games = {}
IO.readlines( ARGV[0])[1..-1].each do |line|
    next if /^\s*$/ =~ line
    els = line.chomp.split( "\t")
    games[ els[0]] = els[1]
end

# 
# Add in new games from app store
#
xml = IO.readlines( ARGV[1]).join
doc = REXML::Document.new xml
REXML::XPath.match( doc, "//feed/entry").each do |item|
    if item.elements[ "category"].attributes[ "term"] == "Games"
        games[ item.elements[ "id"].text] = item.elements["im:name"].text
    end
end

#
# Save out extended list of games
#
f = File.new( ARGV[0], "w")
f.puts "url\tname"
games.each_pair do |k,v|
    f.puts "#{k}\t#{v}"
end
f.close
