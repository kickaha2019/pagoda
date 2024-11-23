path   = '/Users/peter/Caches/Pagoda/verified'
cached = Dir.entries( path).entries.select {|f| /\.html$/ =~ f}
cached.each do |f|
  if m = /^(.*)\.html$/.match( f)
    day = (m[1].to_i / (24 * 60 * 60)) % 10
    system "mv #{path}/#{f}  #{path}/#{day}/#{f}"
  end
end

# raise 'Mistake'
#
# File.open( 'link1.tsv', 'w') do |io|
#   IO.readlines( 'link.tsv').each do |line|
#     fields = line.chomp.split( "\t")
#     if m = /&#8216;(.*?)&#8217; /.match( fields[2])
#       fields[2] = m[1]
#     end
#     io.puts fields.join("\t")
#   end
# end
#

# require_relative 'pagoda'
# pagoda = Pagoda.new( ARGV[0])
#
# links = pagoda.links
# count = 0
#
# links.each do |link|
#   url = pagoda.get_site_handler( link.site).coerce_url( link.url)
#   if url != link.url
#     count += 1
#     if pagoda.link( url)
#       puts "*** Duplicate: #{link.url}"
#       pagoda.start_transaction
#       pagoda.delete( 'link', :url, link.url)
#       pagoda.delete( 'bind', :url, link.url)
#       pagoda.end_transaction
#     elsif link.bound?
#       puts "*** Bound: #{link.url}"
#       g = link.collation
#       pagoda.start_transaction
#       pagoda.delete( 'link', :url, link.url)
#       pagoda.delete( 'bind', :url, link.url)
#       pagoda.end_transaction
#       pagoda.add_link( link.site, link.type, link.title, url, link.static)
#       pagoda.link( url).bind( g ? g.id : -1)
#     else
#       puts "*** Free: #{link.url}"
#     end
#   end
# end
#
# puts "#{count} issues"