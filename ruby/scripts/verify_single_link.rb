require_relative '../verifier'

pagoda   = Pagoda.release( ARGV[0], ARGV[2])

vl = Verifier.new(pagoda)
vl.verify_url( ARGV[1])
puts "... Verified #{ARGV[1]}"
