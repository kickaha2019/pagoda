require_relative '../database'

database = Database.new(ARGV[0])
lost     = []
database.select('bind') do |bind|
  unless database.has?('link', :url, bind[:url])
    lost << bind[:url]
  end
end

puts "#{lost.size} lost binds"
