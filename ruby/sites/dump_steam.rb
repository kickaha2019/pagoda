require 'json'

if ! system( "curl -o /tmp/steam.json https://api.steampowered.com/ISteamApps/GetAppList/v2/")
	raise 'Error retrieving steam data'
end

File.open( '/tmp/steam.csv', 'w') do |io|
  io.puts 'app,name'
	raw = JSON.parse( IO.read( '/tmp/steam.json'))['applist']['apps']
	raw.each do |record|
    io.puts "#{record['appid']},#{record['name']}"
  end
end
