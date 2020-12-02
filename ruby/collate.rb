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
m.load_names( ARGV[0], true)
m.load_names( ARGV[1], false)
m.derive_names

m.load_binds( ARGV[2])
# raise m.simplify( 'Cognition: An Erica Reed Thriller - Episode 1: The Hangman')
m.process_scan( ARGV[3], ARGV[4])
