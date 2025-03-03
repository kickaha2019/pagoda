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
  erb :status
end

post '/add_game_from_link/:url' do
  add_game_from_link( d(params[:url]))
end

get '/aliases' do
  erb :aliases, :locals => get_locals( params, :search => '', :page => 1)
end

get '/aspects' do
  erb :aspects, :locals => get_locals(params, :aspect_type => '')
end

get '/aspect_types' do
  erb :aspect_types
end

post '/aspect_delete/:aspect' do
  aspect_delete( d(params[:aspect]))
end

post '/bind/:url' do
  bind_link( d(params[:url]))
end

post '/bind/:url/:game' do
  bind_link( d(params[:url]), params[:game].to_i)
end

get '/cache/:timestamp' do
  content_type 'text/plain'
  cached_digest( params[:timestamp].to_i).to_yaml
end

post '/check_name' do
  data = JSON.parse( request.body.read)
  #p [data['name'], data['id']]
  check_name( data['name'], data['id'])
end

get '/collation/:url' do
  collation( d(params[:url])).to_json
end

get '/companies' do
  erb :companies, :locals => get_locals( params, :search => '', :page => 1, :known => 'Y')
end

get '/company/:company' do
  erb :company, :locals => {:company => d(params['company'])}
end

post '/company_add/:company' do
  company_add( d(params[:company]))
end

post '/company_alias/:company/:alias' do
  company_add_alias( d(params[:company]), d(params[:alias]))
end

post '/company_delete/:company' do
  company_delete( d(params[:company]))
end

post '/delete_game' do
  delete_game( params[:id].to_i)
  redirect '/new_game'
end

get '/digest/:url' do
  content_type 'text/plain'
  get_digest_as_yaml( d(params[:url]))
end

post '/duplicate_game' do
  new_id = duplicate_game( params[:id].to_i)
  redirect "/game/#{new_id}/"
end

post '/forget/:url' do
  delete_link( d(params[:url]))
end

get '/game/:id' do
  erb :game, :locals => {:id => params[:id].to_i, :context => 0}
end

get '/game/:id/' do
  erb :game, :locals => {:id => params[:id].to_i, :context => 0}
end

get '/game/:id/:context' do
  erb :game, :locals => {:id => params[:id].to_i, :context => params[:context].to_i}
end

post '/game' do
  update_game( params)
  erb :game, :locals => {:id => params[:id].to_i, :context => params['context'].to_i}
end

get '/games' do
  if params[:year]
    context = new_year_context(params[:year],params[:sort_by])
  elsif params[:company]
    context = new_company_context(d(params[:company]),params[:sort_by])
  elsif params[:aspect]
    context = new_aspect_context(d(params[:aspect]),params[:sort_by])
  elsif params[:no_aspect_type]
    context = new_no_aspect_type_context(params[:no_aspect_type],params[:sort_by])
  elsif params[:context]
    context = params[:context].to_i
  else
    context = 0
  end
  erb :games,
      :locals => get_locals( params,
                             :context => context,
                             :search => '',
                             :page => 1,
                             :selected => 0,
                             :x => 0,
                             :y => 0)
end

get '/games_check_inventory_aspect' do
  erb :games_check_inventory_aspect
end

get '/games_check_person_aspects' do
  erb :games_check_person_aspects
end

get '/games_check_resolution_aspects' do
  erb :games_check_resolution_aspects
end

post '/ignore/:url' do
  ignore_link( d(params[:url]))
end

get '/ignored_to_reprieve' do
  erb :ignored_to_reprieve, :locals => get_locals( params, :page => 1)
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

get '/multiple_genre' do
  erb :multiple_genre, :locals => get_locals( params, :page => 1)
end

get '/new_game' do
  erb :game, :locals => {:id => -1, :context => 0}
end

post '/pardon/:url' do
  pardon_link( d(params[:url]))
end

get '/problem_links' do
  erb :problem_links, :locals => get_locals( params, :search => '', :page => 1)
end

post '/redirect/:url' do
  redirect_link( d(params[:url]))
end

get '/reports' do
  erb :reports
end

get '/scans' do
  erb :scans, :locals => {:field => 'found'}
end

get '/scans/:field' do
  erb :scans, :locals => {:field => params[:field]}
end

get '/selected_game' do
  selected_game
end

post '/set_aspect/:game/:aspect/:flag' do
  set_aspect( params[:game].to_i, d(params[:aspect]), params[:flag])
end

post '/set_official_checked/:game' do
  set_official_checked( params[:game].to_i)
end

post '/set_checked/:game/:flag' do
  set_checked( params[:game].to_i, params[:flag])
end

put '/set_variable/:name/:value' do
  set_variable( params[:name], params[:value])
end

get '/sites' do
  erb :sites, :locals => get_locals( params,
                                     :database    => true,
                                     :official    => true,
                                     :reference   => true,
                                     :review      => true,
                                     :store       => true,
                                     :walkthrough => true,)
end

get '/suggests' do
  erb :suggests, :locals => get_locals( params, :search => '', :page => 1, :site => 'All', :type => 'All')
end

get '/suggested_links/:game' do
  erb :suggested_links, :locals => {id:params[:game].to_i}
end

get '/tables' do
  erb :tables
end

get '/tag/:tag' do
  erb :tag, :locals => {:tag => d(params[:tag])}
end

post '/tag' do
  update_tag( params)
  erb :tag, :locals => {:tag => d(params[:tag])}
end

get '/tags' do
  erb :tags, :locals => get_locals( params, :search => '', :page => 1, :aspect => 'All')
end

post '/unbind/:url' do
  unbind_link( d(params[:url]))
end

get '/unchecked_bound_official_websites' do
  erb :unchecked_bound_official_websites, :locals => get_locals( params, :page => 1)
end

get '/unchecked_genre' do
  erb :unchecked_genre, :locals => get_locals( params, :page => 1)
end

get '/verified' do
  erb :verified, :locals => get_locals( params, :search => '', :page => 1, :site => 'All', :type => 'All', :status => 'All')
end

post '/visited/:key' do
  visited_key( d(params[:key]))
end

post '/write_grabbed/:game_id' do
  File.open(ARGV[0] + '/grabbed.txt', 'a') do |io|
    io.puts params[:game_id]
  end
end
