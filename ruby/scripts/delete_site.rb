require 'net/http'
require 'net/https'
require 'uri'
require_relative '../pagoda'

$pagoda = Pagoda.release( ARGV[0])

def links
  $pagoda.links do |link|
    /www.pcgameswalkthroughs.nl/ =~ link.url
  end.each {|link| yield link}
end

links do |link|
  link.delete
  p [link.title, link.url]
end

