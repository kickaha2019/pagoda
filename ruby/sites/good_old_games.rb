require_relative 'default_site'

class GoodOldGames < DefaultSite
  def initialize
    @info         = nil
    @info_changed = 0
  end

	def extract_card_product( html)
		html.split("\n").each do |line|
			if m = /^\s*cardProduct: ({.*)\s*,\s*$/.match( line)
				return JSON.parse( m[1])
			end
		end
		false
	end

	def find( scanner)
		path = scanner.cache + "/gog.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			urls, page, added = {}, 0, 1

			while (added > 0) && (page < 1000)
				added = 0
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page+1}&order=asc:releaseDate"
				#File.open( '/Users/peter/temp/gog.html', 'w') {|io| io.print raw}
				#raw = IO.read( '/Users/peter/temp/gog.html')

				url = nil
				raw.split( '<').each do |line|
					if m = /href="(https:\/\/www\.gog\.com\/game\/[^"]*)"/.match( line)
						url = m[1]
					end
					if m = /title="([^"]*)"/.match( line)
						if url
							text = m[1]
							text.force_encoding( 'UTF-8')
							text.encode!( 'US-ASCII',
														:invalid => :replace, :undef => :replace, :universal_newline => true)
							added += scanner.add_link( text, url)
              url = nil
            end
          end
				end

				page += 1
			end
		end

		# JSON.parse( IO.read( path)).each_pair do |url, name|
		# 	scanner.suggest_link( name, url)
		# end
		#
		# scanner.purge_lost_urls( /^https:\/\/www\.gog\.com\//)
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*) on GOG\.com$/.match( rec[:title].strip)
			rec[:title] = m[1]
			if m1 = /^\-\d+% (.*)$/.match( rec[:title])
				rec[:title] = m1[1]
			end
		else
			rec[:valid]   = false
			rec[:comment] = 'Unexpected title'
			return false
		end

		@info = pagoda.get_yaml( 'gog.yaml') if @info.nil?
		tags  = @info['tags']
		found = ''

		if m = /"tags":\[([^\]]*)\]/mi.match( page)
			found += m[1]
		end

		if m = /"gameTags":\[([^\]]*)\]/mi.match( page)
			found += m[1]
		end

		if found == ''
			rec[:valid]   = false
			rec[:comment] = 'No tags'
			return false
		end

		rec[:ignore] = true
		found.scan( /"name":"([^"]*)"/) do |tag|
			if tags[tag[0]] == 'accept'
				rec[:ignore] = false
      elsif tags[tag[0]].nil?
        tags[tag[0]] = 'ignore'
        @info_changed += 1
			end
		end

		found.scan( /"name":"([^"]*)"/) do |tag|
			if tags[tag[0]] == 'reject'
				rec[:ignore] = true
			end
		end

		true
	end

	def get_game_description( page)
		if info = extract_card_product( page)
			info['description'] + ' ' + info['tags'].collect {|tag| tag['slug']}.join( ' ')
		else
			''
		end
	end

	def get_game_details( url, page, game)
		if info = extract_card_product( page)
			game[:name]      = info['title']
			game[:publisher] = info['publisher']
			game[:developer] = info['developers'].collect {|d| d['name']}.join(', ') if info['developers']
			game[:year]      = info['globalReleaseDate'][0..3] if info['globalReleaseDate']
		end
	end

	def incremental( scanner)
		# puts "*** Awaiting full scan to be done"
		# return
		# path   = scanner.cache + "/gog.json"
		# cached = JSON.parse( IO.read( path))

		scanner.twitter_feed_links( 'gogcom') do |text, link|
			if /^https:\/\/www\.gog\.com\/game\// =~ link
				link = link.split('?')[0]
				scanner.add_link( '', link)
			# 	if cached[link]
			# 		0
			# 	else
			# 		cached[link] = ''
			# 		1
			# 	end
			else
				0
			end
		end

		# if added > 0
		# 	File.open( path, 'w') {|io| io.print JSON.generate( cached)}
		# end
		# added
	end

	def name
		'GOG'
  end

  def terminate( pagoda)
    if @info_changed > 0
      pagoda.put_yaml( @info, 'gog.yaml')
      puts "... #{@info_changed} tags added to gog.yaml"
    end
  end
end