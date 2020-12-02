#!/bin/ruby
=begin
	Collate scan names against game names
	
	Arguments:
		Game data
		Alias data
		Bind data
		Scan data
		Output collation file
=end

load 'matcher.rb'

m = Matcher.new
m.load_names( ARGV[0], false)
m.load_names( ARGV[1], false)
m.derive_names( /Broken/i)

m.load_binds( ARGV[2])
#m.list_names( /Spy Fox/i)
m.process_scan_line( 1, "?", "#14 Nancy Drew: Danger by Design", "?", STDOUT, true)
