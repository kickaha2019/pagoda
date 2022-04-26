if File.exist?( 'transaction.txt')
  raise '*** Active transactions'
end

lines = IO.readlines( 'aspect.tsv').collect {|l| l.chomp}
deleted = 0

File.open( 'aspect.tsv', 'w') do |io|
  lines.each do |line|
    if line.split("\t")[1] == ARGV[0]
      deleted += 1
    else
      io.puts line
    end
  end
end

puts "... #{deleted} deleted"