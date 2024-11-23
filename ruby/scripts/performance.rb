require 'net/http'
require 'net/https'
require 'uri'
require_relative '../database'
require_relative '../pagoda'

def log( msg)
  puts "#{Time.now.strftime('%H:%S.%L')} - #{msg}"
end

log "Start"
Pagoda.release(ARGV[0])
log "Opened Pagoda"
