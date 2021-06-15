#!/bin/ruby
=begin
	Matcher class
=end

class Matcher
	def initialize
		@name2id     = {}
		@name_refs   = {}
		@id2name     = {}
		@id2year     = {}
		@binds       = {}
		@binds_used  = {}
		@site_counts = Hash.new {|h,k| h[k] = 0}
		
		@bound           = 0
		@unbound         = 0
		@matched         = 0
		@unmatched       = 0
		@binds_redundant = 0
	end
	
	def add_name( file, i, name, id, ignore = false)
		s = simplify( name)
		return if @name2id[s] and not file
		if @name2id[s] and @name2id[s] == id
			puts "**** Name [#{name}] multiply defined at #{file}/#{i} and #{@name_refs[s]}" if not ignore
		elsif @name2id[s]
			raise "**** Name [#{name}] conflict at #{file}/#{i} and #{@name_refs[s]}" if not ignore
		else
			@name2id[s] = id
			@name_refs[s] = "#{file}/#{i}"
			@id2name[id] = [] if not @id2name[id]
			@id2name[id] << s
		end
	end

	# For games with two names handle where site lists games under a compound name
	# Allow "episode" "book" "chapter" "case" "act" "vol" to be omitted
	# If game name ends in " 1" allow the " 1" to be optional
	def derive_names( regex = nil)
		was = @name2id.size
		
		@id2name.each_pair do |id,names|
			names.each do |name|
				puts "Derive1: #{name}" if regex and regex =~ name
				if m = /^(.*) and (.*)$/.match( name)
					add_name( nil, nil, m[1] + ' ' + m[2], id)
				end
			end
		end

		@id2name.each_pair do |id,names|
			names.each do |name|
				if m = /^(.*) (episode|book|case|chapter|act|vol|volume|and) (.*)$/.match( name)
					add_name( nil, nil, m[1] + ' ' + m[3], id, true)
				end
				
				if m = /^(.*) (episode|book|case|chapter|act|vol|volume) 1 (.*)$/.match( name)
					add_name( nil, nil, m[1] + ' ' + m[3], id, true)
				end
				
				if m = /^(.*) (episode|book|case|chapter|act|vol|volume) 1$/.match( name)
					add_name( nil, nil, m[1], id, true)
				end
				
				if m = /^(.*) (1|1a)$/.match( name)
					add_name( nil, nil, m[1], id)
				end
				
				if m = /^(.*) (1|1a) (.*)$/.match( name)
					add_name( nil, nil, m[1]+' '+m[3], id)
				end
				
				if m = /^(.*)'s (.*)$/.match( name)
					add_name( nil, nil, m[1] + ' ' + m[2], id, true)
				end
			end
		end
		
		puts "#{@name2id.size - was} names derived"
	end

	def find_column( file, columns, name)
		index = columns.index( name)
		raise "No column [#{name}] in file [#{file}]" if not index
		index
	end

	def list_names( regex)
		@name2id.keys.sort.each do |name|
			puts "*** #{name}" if regex =~ name
		end
	end
	
	def load_binds( file)
		lines = IO.readlines( file)
		columns = lines[0].chomp.split("\t")
		url_col = find_column( file, columns, 'url')
		id_col = find_column( file, columns, 'id')
		
		(1...lines.size).each do |i|
			data = lines[i].chomp.split( "\t")
			next if data.size < 2
			id = data[id_col].to_i
			url = data[url_col]
			if @binds[url]
				raise "**** URL [#{url}] multiply defined at line #{i} file #{file}"
			else
				@binds[url] = id
			end
		end

		puts "#{@binds.size} binds loaded from #{file}"
	end

	def load_names( file, grouped)
		was = @name2id.size
		
		lines = IO.readlines( file)
		columns = lines[0].chomp.split("\t")
		id_col = find_column( file, columns, 'id')
		name_col = find_column( file, columns, 'name')
		year_col = columns.index( 'year')
		group_col = grouped ? find_column( file, columns, 'is_group') : 0
		
		(1...lines.size).each do |i|
			data = lines[i].chomp.split( "\t")
			next if data.size < 2
			next if grouped and data[group_col] == 'Y'
			id = data[id_col].to_i
			name = data[name_col]
			add_name( file, i, name, id)
			
			if m = /^(.*): (.*)$/.match( name)
				add_name( file, i, m[2] + ': ' + m[1], id, true)
			end

			if m = /^(.*)\W+\d+:\W+(.*)$/.match(name)
				add_name( file, i, m[1]+' '+ m[2], id, true)
			end
			
			if m = /^(.*)\W+(\d+)a:\W+(.*)$/i.match(name)
				add_name( file, i, m[1]+' '+m[2]+': '+m[3], id, true)
			end
			
			if year_col and (year_col >= 0) and data[year_col] != ''
				@id2year[id] = data[year_col].to_i
			end
		end
		
		puts "#{@name2id.size - was} names loaded from #{file}"
	end

	def match( name, debug)
		puts ">>> Trying [#{name}] simplified to [#{simplify(name)}]" if debug
		@name2id[ simplify( name)]
	end
	
	def process_scan( scan, output)
		lines = IO.readlines( scan)
		columns = lines[0].chomp.split("\t")
		id_col = find_column( scan, columns, 'id')
		site_col = find_column( scan, columns, 'site')
		name_col = find_column( scan, columns, 'name')
		url_col = find_column( scan, columns, 'url')
		
		@bound = 0
		@unbound = 0
		@matched = 0
		@unmatched = 0
		@binds_redundant = 0
		
		File.open( output, "w") do |f|
			f.puts "id\tlink\tlength"
			(1...lines.size).each do |i|
				data = lines[i].chomp.split( "\t")
				next if data.size < 2
				process_scan_line( data[id_col], data[site_col], data[name_col], data[url_col], f)
			end
		end
		
		@binds.keys.each do |url|
			puts "**** Unused bind: #{url}" if not @binds_used[url]
		end
		
		puts "#{@bound} scans bound"
		puts "#{@unbound} scans unbound"
		puts "#{@binds_redundant} binds redundant"
		puts "#{@matched-@bound} scans matched"
		puts "#{@matched} scans collated"
		puts "#{@unmatched} scans not matched"
		puts ""

		@site_counts.each_pair do |k,v|
			puts "#{k} - #{v}" if ['GOG','iOS','Steam'].include?( k)
		end
	end

	def process_scan_line( link, site, name, url, output, debug = false)
		id = match( name, debug)
		
		if not id
			if m = /(.*)(:|,|-)(.*)/i.match( name)
				id1,id2 = match( m[1], debug), match(m[3], debug)
				id = id1 if id1 == id2
			end
		end
		
		if not id
			if m = /(.*): (.*) - (.*)/i.match( name)
				id1 = match( m[1] + ': ' + m[2], debug)
				id2 = match( m[1] + ': ' + m[3], debug)
				id = id1 if id1 == id2
			end
		end
		
		if not id
			if m = /(.*) aka (.*)/i.match( name)
				id1,id2 = match( m[1], debug), match(m[2], debug)
				id = id1 if id1 == id2
			end
		end
		
		if not id
			if m = /(.*) \/ (.*)/i.match( name)
				id1,id2 = match( m[1], debug), match(m[2], debug)
				id = id1 if id1 == id2
			end
		end
		
		if not id
			parts = name.split( ';')
			if parts.size > 1
				id = match( parts[0], debug)
				parts[1..-1].each do |part|
					next if id.nil?
					id = nil if id != match( part, debug)
				end
			end
		end
		
		if not id
			if m = /(.*) \((.*)\)/i.match( name)
				id1,id2 = match( m[1], debug), match(m[2], debug)
				id = id1 if id1 == id2
			end
		end
		
		if not id
			if m = /(.*) \(aka (.*)\)/i.match( name)
				id1,id2 = match( m[1], debug), match(m[2], debug)
				id = id1 if id1 == id2
			end
		end
		
#		if not id
#			if m = /(.*) chapter I: (.*)/i.match( name)
#				id = match( m[1]+' chapter 1: '+ m[2])
#			end
#		end
		
		if not id
			if m = /(.*), (.*)$/.match( name)
				id = match( m[2]+' '+ m[1], debug)
			end
		end

		if @binds[url]
			@binds_used[url] = true
			
			if @binds[url] < 1
				@unbound += 1
				return
			end

			@bound += 1
			if @binds[url] == id
				@binds_redundant += 1
				puts "**** Redundant bind for #{id} / #{site} / #{name} / #{url}"
			else
				id = @binds[url]
			end
		end

		if id
			output.puts "#{id}\t#{link}\t1"
			@matched += 1
			@site_counts[site] += 1
			return
		end
		
		@unmatched += 1
		puts "**** Unmatched: #{id} / #{site} / #{name} / #{url}" if debug
	end

	# Replace certain strings
	# A.B.C. -> ABC
	def simplify( name)
		{"&nbsp;"   => " ", "&#8216;" => "'", "&#8217;" => "'",
		 "&amp;"    => "and",
		 "&#8211;"  => " ",
		 "&#8220;"  => " ", "&#8221;" => " ", "&#x27;"   => "'",
		 "&#039;"   => "'",
		 "&egrave;" => "e", "&ocirc;" => "o", "&eacute;" => "e",
		 "&uuml;"   => "u", "&quot;"  => '"'
		}.each_pair do |p,r|
			name = name.gsub( p, r)
		end
		
		{"-" => " ", ":" => " ", "#" => " ", "?" => " ", "(" => " ",
		 ")" => " ", "…" => " ",
		 "," => " ", "!" => " ", "." => " ", '"' => " ", "'" => " "}.each_pair do |p,r|
			name = name.gsub( p, r)
		end
		
		words = name.downcase.split( /\s+/)
		replace = {"zero" => "0", "i" => "1", "one" => "1", "two" => "2", "ii" => "2",
				   "iii" => "3", "three" => "3", "four" => "4", "iv" => "4",
				   "v" => "5", "five" => "5", "six" => "6", "vi" => "6",
				   "vii" => "7", "nine" => "9", "the" => "", "a" => "", "an" => "",
				   "1st" => "first", "2nd" => "second",
				   "&" => "and", "6th" => "sixth", "vol" => "volume",
				   "center" => "centre", "color" => "colour",
				   "vs" => "versus"}
		words = words.collect do |w|
			replace[w] ? replace[w] : w
		end

		#words = words.collect do |w|
		#	if /^([^\.]\.)*$/ =~ w
		#	  w.split( "\.").join( '')
		#	else
		#	  w
		#	end
		#end
		name1 = words.join( ' ')
		while (name2 = name1.gsub( '  ', ' ')) != name1 do
			name1 = name2
		end
		name1 = name1.strip
		
		return name if name1 == ''
		name1
	end
	
	def write_search_patterns( file)
		File.open( file, "w") do |f|
			@name2id.each_key do |name|
				raise "Bad name [#{name}]" if /[&!=\.?"!\(\)+]/ =~ name
				year = @id2year[@name2id[name]]
				year_pattern = year ? "(#{year-1}|#{year}|#{year+1})" : '.*'
				urlencode = name.gsub( ' ', '+').gsub( "'", '%27')
				pattern = '(^|.*\W)' + name.gsub( ' ', '(\W|\W.*\W)') + '($|\W.*)'
				f.puts "#{urlencode}\t#{pattern}\t#{year_pattern}"
			end
		end
	end
end
