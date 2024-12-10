require 'yaml'

File.open(ARGV[1],'w') do |io|
	io.puts "tag\taspect"
	yaml = YAML.load(IO.read(ARGV[0]))
	yaml['All'].each_pair do |key,value|
		if value.is_a? String
			io.puts "#{key}\t#{value}"
		elsif value.empty?
			io.puts "#{key}\t"
		else
			value.each {|v| io.puts "#{key}\t#{v}"}
		end
	end
end
