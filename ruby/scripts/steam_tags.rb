require_relative '../pagoda'
require 'yaml'

pagoda = Pagoda.new( ARGV[0])

counts = Hash.new {|h,k| h[k] = 0}
tags   = {}

pagoda.links do |link|
  next unless link.site == 'Steam'
  next if link.orig_title == 'Welcome to Steam'
  next unless link.valid?
  page = IO.read( ARGV[1] + "/#{link.timestamp}.html").split("\n").join( ' ')
  found = false
  page.scan( /<a\s+href="https:\/\/store.steampowered.com\/tags\/en\/[^>]*>([^<]*)</) do |tag|
    tags[tag[0].strip] = 'ignore'
    counts[tag[0].strip] += 1
    found = true
  end
  # unless found
  #   File.open( '/tmp/steam.html', 'w') {|io| io.puts page}
  #   p link.orig_title
  #   raise 'Dev2'
  # end
end

p counts.size

File.open( ARGV[2], 'w') do |io|
  io.puts "Tag,Count"
  counts.keys.sort.each do |tag|
    io.puts "#{tag},#{counts[tag]}"
  end
end

File.open( ARGV[3], 'w') do |io|
  io.print( {'tags' => tags}.to_yaml)
end