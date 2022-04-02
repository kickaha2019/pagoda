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

post '/add_game_from_link/:url' do
  add_game_from_link( d(params[:url]))
end

get '/aliases' do
  erb :aliases, :locals => get_locals( params, :search => '', :page => 1)
end

post '/bind/:url' do
  bind_link( d(params[:url]))
end

post '/bind/:url/:game' do
  bind_link( d(params[:url]), params[:game].to_i)
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
  erb :games, :locals => get_locals( params, :search => '', :page => 1, :selected => 0, :x => 0, :y => 0)
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

get '/links' do
  erb :links, :locals => get_locals( params, :search => '', :page => 1, :site => 'All', :type => 'All', :status => 'All')
end

get '/new_game' do
  erb :game, :locals => {:id => -1}
end

put '/reverify/:url' do
  reverify( d(params[:url]))
end

get '/selected_game' do
  selected_game
end

post '/set_aspect/:game/:aspect/:flag' do
  set_aspect( params[:game].to_i, d(params[:aspect]), params[:flag])
end

put '/set_variable/:name/:value' do
  set_variable( params[:name], params[:value])
end

get '/suggest_aspects' do
  erb :suggest_aspects, get_locals( params, :page => 1)
end

get '/summary' do
  erb :summary, :locals => get_locals( params,
                                       :official    => true,
                                       :reference   => true,
                                       :review      => true,
                                       :store       => true,
                                       :walkthrough => true)
end

post '/unbind/:url' do
  unbind_link( d(params[:url]))
end

get '/verified' do
  erb :verified, :locals => get_locals( params, :search => '', :page => 1, :site => 'All', :type => 'All', :status => 'All')
end
