require_relative 'default_site'

class GOG < DefaultSite
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

	def filter( info, page, rec)
		p ['filter1', rec]
		tags  = info['tags']
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
				rec[:valid]   = false
				rec[:comment] = 'Unknown tag: ' + tag[0]
				return false
			end
		end

		p ['filter2', rec]
		found.scan( /"name":"([^"]*)"/) do |tag|
			p [tag, tags[tag[0]]]
			if tags[tag[0]] == 'reject'
				rec[:ignore] = true
			end
		end

		true
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
end
