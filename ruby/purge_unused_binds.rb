#!/bin/ruby
=begin
	Purge unused and redundant binds
=end

# Load binds into a hash by game ID
binds = {}
IO.readlines( ARGV[1])[1..-1].each do |line|
    els = line.chomp.split( "\t")
    next if els.size != 2
    binds[els[0]] = els[1]
end

# Delete any listed in collate.log
IO.readlines( ARGV[0]).each do |line|
    if m = /Redundant bind for .* (http.*)$/.match( line.chomp)
        raise "Error deleting bind: #{m[1]}" if not binds.delete( m[1])
    end
	
    if m = /Unused bind: (http.*)$/.match( line.chomp)
        raise "Error deleting bind: #{m[1]}" if not binds.delete( m[1])
    end
end

# Rewrite the file
f = File.new( ARGV[1], "w")
f.puts "url\tid"

# Loop through all the games and their matches
binds.each_pair do |url,id|
    f.puts "#{url}\t#{id}"
end

f.close
