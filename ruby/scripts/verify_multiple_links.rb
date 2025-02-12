require_relative '../verifier'

pagoda   = Pagoda.release( ARGV[0])

vl = Verifier.new(pagoda)
puts "... Verifying links"
count = 0
vl.to_verify(ARGV[1].to_i) do |link|
  #puts "... Verifying #{link.url}"
  count += 1
  begin
    vl.verify_page( link)
  rescue
    puts "*** Problem with #{link.url}"
    raise
  end
end
puts "... Verified #{count} links"
