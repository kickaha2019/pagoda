#!/bin/ruby
=begin
	Merge text files filtering out certain character sequences
	
	Command line arguments are a set of input files to be
	merged ending with the output file
=end

of = File.new( ARGV[-1], "w")
ARGV[0,ARGV.size-1].each { |file|
	File.new( file).readlines.each { |line|
		line.force_encoding( 'UTF-8')
		line = line.encode( 'US-ASCII',
							:invalid => :replace,
							:undef => :replace,
							:universal_newline => true)
		while (line.sub!( /\\N/, '') != nil) do end
		while (line.sub!( /\\/, '') != nil) do end
		of.puts line.chomp
	}
}
of.close
