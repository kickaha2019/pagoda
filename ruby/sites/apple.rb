require 'json'
require_relative 'default_site'

class Apple < DefaultSite
  @@sections = {'adventure' => 7002, 'puzzle' => 7012, 'role-playing' => 7014}
  @@letters  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ*'

  def extract_ember_json( html)
    inside, text = false, []
    html.split("\n").each do |line|
      if m = /^\s*<script[^>]*>({.*)$/.match( line)
        return JSON.parse( m[1])
      end

      if /^\s*<script name="schema:software-application"/ =~ line
        inside = true
      elsif inside
        return JSON.parse( line)
      end
    end

    false
  end

  def full( scanner)
    scanner.link_page_anchors( 'TouchArcade') do |game, url, text|
      if text.downcase == 'buy now'
        if m = /\/link\/.*apple\.com.*\/app\/(.*)\?/.match( url)
          scanner.add_link( game, "https://apps.apple.com/app/#{m[1]}")
        end
      end
    end

    Dir.entries( scanner.cache + '/ios').each do |f|
      if /\.json$/ =~ f
        JSON.parse( IO.read( scanner.cache + '/ios/'+ f))['urls'].each_pair do |url,name|
          scanner.suggest_link( name, url)
        end
      end
    end

    scanner.purge_lost_urls( /^https:\/\/apps\.apple\.com\//)
  end

  def get_cache_info( searcher)
    info = []
    @@sections.each_key do |section|
      @@letters.each_char do |letter|
        path = get_cache_path( searcher, section, letter)
        t = 0
        if File.exist?( path)
          t = File.mtime( path).to_i
        end
        info << [section, letter, t]
      end
    end
    info
  end

  def get_cache_path( searcher, section, letter)
    index = @@letters.index( letter)
    searcher.cache + "/ios/#{section}#{index+1}.json"
  end

  def get_game_description( page)
    if json = extract_ember_json( page)
      json['description']
    else
      page
    end
  end

  def get_game_details( url, page, game)
    if json = extract_ember_json( page)
      if dp = json['datePublished']
        if m = /(\d\d\d\d)/.match( dp)
          game[:year] = m[1]
        end
      end
      if author = json['author']
        game[:developer] = game[:publisher] = author['name']
      end
    end
  end

	def incremental( scanner)
		scanner.twitter_feed_links( 'applearcade') do |text, link|
      if m = match_link( link)
				scanner.add_link( '', "https://apps.apple.com/app/#{m[1]}")
			else
				0
			end
    end

    scanner.twitter_feed_links( 'appstoregames', 1000) do |text, link|
      if m = match_link( link)
        #io.puts "... #{link}"
        scanner.add_link( '', "https://apps.apple.com/app/#{m[1]}")
      else
        #io.puts "??? #{link}"
        0
      end
    end
	end

  def match_link( link)
    m = /^https:\/\/apps\.apple\.com\/\w\w\/app\/[^\/]*\/(id[0-9]*)\?/.match( link)
    unless m
      m = /^https:\/\/apps\.apple\.com\/app\/[^\/]*\/(id[0-9]*)\?/.match( link)
    end
    unless m
      m = /^https:\/\/apps\.apple\.com\/app\/(id[0-9]*)\?/.match( link)
    end
    m
  end

  def refresh_cache( searcher, section, letter)
    path = get_cache_path( searcher, section, letter)

    puts "... Scanning iOS #{section} apps letter #{letter}"
    page, loop, letter_urls = 0, true, {}
    while loop && (page < 200)
      page += 1
      old_size = letter_urls.size
      raw = searcher.http_get( "https://apps.apple.com/us/genre/ios-games-#{section}/id#{@@sections[section]}?letter=#{letter}&page=#{page}")
      sleep 15
      raw.split( '<li>').each do |line|
        if m = /<a href="(https:\/\/apps.apple.com\/us\/app\/[^"]*)">([^>]*)</.match(line)
          text = m[2]
          text.force_encoding( 'UTF-8')
          text.encode!( 'US-ASCII',
                        :invalid => :replace, :undef => :replace, :universal_newline => true)
          letter_urls[m[1]] = text
        end
      end
      loop = (old_size < letter_urls.size)
    end

    raise "Too many IOS games" if loop
    File.open( path, 'w') {|io| io.print JSON.generate( {'urls' => letter_urls})}
  end

  def search( searcher)
    caches = get_cache_info( searcher).sort_by {|cache| cache[2]}
    caches[0..2].each do |cache|
      refresh_cache( searcher, cache[0], cache[1])
    end
    0
  end
end
