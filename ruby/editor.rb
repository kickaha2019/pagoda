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

get '/scan' do
  erb :scan
end
