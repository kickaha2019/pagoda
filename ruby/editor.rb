require 'sinatra'

require_relative 'editor_helper'

configure do
  enable :lock
  Sinatra::EditorHelper::setup
end

before do
  cache_control :no_cache
  refresh_metadata
end

get '/' do
  erb :tables
end

get '/aliases' do
  erb :aliases
end

get '/aliases_list' do
  erb :aliases_list
end

get '/cache/:timestamp' do
  get_cache( params[:timestamp].to_i)
end

get '/check_name/:id/:name' do
  check_name( params[:name], params[:id])
end

get '/collation/:url' do
  collation( d(params[:url])).to_json
end

post '/bind/:url' do
  bind_link( d(params[:url]))
end

post '/delete_game' do
  delete_game( params[:id].to_i)
  redirect '/new_game'
end

post '/forget/:url' do
  delete_link( d(params[:url]))
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

get '/get_variable/:name' do
  get_variable( params[:name])
end

post '/ignore/:url' do
  ignore_link( d(params[:url]))
end

delete '/link/:url' do
  delete_link( d(params[:url]))
end

get '/link/:url' do
  erb :link_record, :locals => {:url => d(params[:url])}
end

get '/link_list' do
  erb :link_list
end

get '/links' do
  erb :links
end

get '/new_game' do
  erb :game, :locals => {:id => -1}
end

get '/page_control/:kind' do
  erb :page_control, :locals => {:kind => params[:kind]}
end

put '/reverify/:url' do
  reverify( d(params[:url]))
end

get '/selected_game' do
  selected_game
end

put '/set_variable/:name/:value' do
  set_variable( params[:name], params[:value])
end

get '/summary' do
  erb :summary
end

post '/unbind/:url' do
  unbind_link( d(params[:url]))
end
