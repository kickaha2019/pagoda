require 'sinatra'
require 'sinatra/cookies'

require_relative 'editor_helper'

configure do
  enable :lock
  Sinatra::EditorHelper::setup
end

get '/' do
  erb :tables
end

get '/check_name/:id/:name' do
  check_name( params[:name], params[:id])
end

get '/collation_link/:id' do
  collation_link( params[:id].to_i)
end

post '/bind/:id' do
  bind_scan( params[:id].to_i)
end

post '/delete_game' do
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

post '/ignore/:id' do
  ignore_scan( params[:id].to_i)
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

get '/scan/:id' do
  erb :scan_record, :locals => {:id => params[:id].to_i}
end

get '/summary' do
  erb :summary
end

post '/unbind/:id' do
  unbind_scan( params[:id].to_i)
end
