require_relative '../pagoda'

$pagoda = Pagoda.release( ARGV[0])

def links
  $pagoda.links do |link|
    (link.site == ARGV[1]) && (link.type == ARGV[2]) && (link.status == ARGV[3])
  end.each {|link| yield link}
end

links do |link|
  #  p [link.title, link.url]
  link.delete
end

