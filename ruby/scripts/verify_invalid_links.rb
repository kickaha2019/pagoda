require_relative '../verifier'

pagoda   = Pagoda.release( ARGV[0], ARGV[2])

vl = Verifier.new(pagoda)

free = pagoda.links do |link|
  link.status == 'Invalid'
end

free.each do |link|
  vl.verify_url( link.url)
end
