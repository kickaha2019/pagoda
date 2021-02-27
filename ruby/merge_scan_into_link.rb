require_relative 'database'

database = Database.new( ARGV[0])

database.select( 'scan') do |rec|
  puts rec[:url]
  unless database.has?( 'link', :url, rec[:url])
    database.start_transaction
    database.insert( 'link',
                     {:site      => rec[:site],
                             :type      => rec[:type],
                             :url       => rec[:url],
                             :timestamp => 1})
    database.end_transaction
  end
end