require 'sinatra'
require_relative 'database'

configure do
  $database = Database.new( ARGV[0])
  $database.join( 'scan', :bind, :url, 'bind', :url)
  $database.join( 'scan', :collate, :id, 'collate', :link)
end

get '/' do
  erb :tables
end

get '/scan' do
  erb :scan, :locals => {:params => params}
end
