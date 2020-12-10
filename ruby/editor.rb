require 'sinatra'
require 'sinatra/cookies'

require_relative 'database'
require_relative 'editor_helper'

configure do
  enable :lock
  $database = Database.new( ARGV[0])
  $database.join( 'scan', :bind, :url, 'bind', :url)
  $database.join( 'scan', :collate, :id, 'collate', :link)
  $database.join( 'game', :aliases, :id, 'alias', :id)
end

get '/' do
  erb :tables
end

get '/delete_game/:id' do
  delete_game( params[:id].to_i)
  redirect '/new_game'
end

get '/game/:id' do
  erb :game, :locals => {:id => params[:id].to_i}
end

post '/game' do
  update_game( params)
  erb :game, :locals => {:id => params[:id].to_i}
end

get '/games' do
  erb :games
end

get '/games_list' do
  erb :games_list
end

get '/new_game' do
  erb :game, :locals => {:id => -1}
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
