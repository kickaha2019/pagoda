#!/bin/ruby
=begin
	Filter Scanner output for
    
    * iTunes multiple listings of same game
=end

def itunes_filter_open
    @itunes_rows = {}
end

def itunes_filter_pass( row)
    return true if row[1] != "iTunes App Store"
    
    priority = 100
    name = row[3]
    
    elide = {/^(.*), HD$/ => 10,
             /^(.*), HD(:.*)$/ => 10,
             /^(.*) HD$/ => 10,
             /^(.*) HD(:.*)$/ => 10,
             /^(.*), \(Premium\)$/ => 10,
             /^(.*) - \(Universal\)$/ => 10,
             /^(.*) Full$/ => 5,
             /^(.*) \(Full\)$/ => 5,
             /^(.*) Plus$/ => 5,
             /^(.*) \(Universal\)$/ => 5,
             /^(.*) Extended Edition$/ => 5,
             /^(.*) Collector's Edition$/ => 5,
             /^(.*) LITE$/ => -10,
             /^(.*) [Ll]ite$/ => -10,
             /^(.*) [Ll]ite(:.*)$/ => -10,
             /^(.*) FREE$/ => -10,
             /^(.*) Free$/ => -10
            }
    
    elided = true
    while elided
        elided = false
        elide.each_pair do |k,v|
            if m = k.match( name)
                name = m[2] ? (m[1] + m[2]) : m[1]
                priority += v
                elided = true
            end
        end
    end
    
    if r = @itunes_rows[name]
        if r[0] < priority
            @itunes_rows[name] = [priority, row]
        end
    else
        @itunes_rows[name] = [priority, row]
    end
    
    false
end

def itunes_filter_close( file)
    @itunes_rows.each_pair do |k, v|
        v[1][3] = k
        file.puts v[1].join( "\t")
    end
end

# Initialise filters
itunes_filter_open

# Copy Scanner output applying the filters
f = File.new( ARGV[1], "w")
IO.readlines( ARGV[0]).each do |line|
    row = line.chomp.split( "\t")
    if itunes_filter_pass( row)
        f.puts line.chomp
    end
end

itunes_filter_close( f)
f.close
