require_relative '../verifier'

pagoda   = Pagoda.release( ARGV[0])

vl = Verifier.new(pagoda)

free = pagoda.links do |link|
  link.comment
end

free.each do |link|
  vl.verify_url( link.url)
end
