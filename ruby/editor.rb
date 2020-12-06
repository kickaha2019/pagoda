require 'sinatra'
require 'sinatra/cookies'

require_relative 'database'
require_relative 'editor_helper'

configure do
  $database = Database.new( ARGV[0])
  $database.join( 'scan', :bind, :url, 'bind', :url)
  $database.join( 'scan', :collate, :id, 'collate', :link)
end

get '/' do
  erb :tables
end

get '/games' do
  erb :games
end

get '/games_list' do
  erb :games_list
end

get '/page_control/:control_id' do
  erb :page_control, :locals => {:control_id => params[:control_id]}
end

get '/scan' do
  erb :scan
end

get '/summary' do
  erb :summary
end
