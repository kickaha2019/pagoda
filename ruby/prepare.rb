#!/bin/ruby
=begin
	Generate search patterns
	
	Arguments:
		Game data
		Alias data
		Output search pattern file
=end

load 'matcher.rb'

m = Matcher.new
m.load_names( ARGV[0], true)
m.load_names( ARGV[1], false)
m.derive_names
m.write_search_patterns( ARGV[2])
