#
# Archive site when its website may have gone
#
# Command line:
#   Site name
#   Old Pagoda verified cache
#   Old Pagoda links data file
#   Pagoda verified cache
#   Pagoda links data file
#   Output links data file
#

# Remove links for site from current links data file
# Delete any verified files for the site
File.open( ARGV[5], 'w') do |io|
  IO.readlines( ARGV[4]).each do |line|
    fields = line.split("\t")
    if fields[0] == ARGV[0]
      path = ARGV[3] + '/' + fields[4] + '.html'
      if File.exist?( path)
        puts "... Deleting #{path}"
        File.delete( path)
      end
    else
      io.print line
    end
  end

  # Add links from old links data file and copy
  # the verified file
  IO.readlines( ARGV[2]).each do |line|
    fields = line.strip.split("\t")
    if fields[0] == ARGV[0]
      while fields.size < 10
          fields << ''
      end
      fields << 'Y'
      io.puts fields.join( "\t")
      path = ARGV[1] + '/' + fields[4] + '.html'
      if File.exist?( path)
        puts "... Copying #{path}"
        unless system( "cp #{path} #{ARGV[3]}/#{fields[4]}.html")
          raise "*** Error copying #{path}"
        end
      end
    end 
  end 
end


