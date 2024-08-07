require_relative 'default_site'

class BigFishGames < DefaultSite
	def deleted_title( title)
		title == 'Store'
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*) &gt;/.match( rec[:title].strip)
			rec[:title] = reduce_title( m[1])
			true
		else
			rec[:valid]   = false
			rec[:comment] = 'Unexpected title: ' + rec[:title].strip
			false
		end
	end

	def full( scanner)
		full1( scanner, 'pc-adventure-games') +
		full1( scanner, 'pc-hidden-object-adventure-games')
	end

	def full1( scanner, type)
		base       = 'https://www.bigfishgames.com/us/en/games/'
		match      = Regexp.new( '^' + base + '\d+/')
		url        = base + "genres/#{type}.html?page="
		found      = 0
		page       = 0
		last_found = -1
		added      = 0

		while last_found < found
			last_found =  found
			page       += 1
			added      += scanner.html_links( url + page.to_s) do |link|
				if match =~ link
					found += 1
					scanner.add_link( '', link.split('?')[0])
				else
					0
				end
			end
		end

		added
	end

	def get_game_description( page)
		page
	end

	def name
		'Big Fish Games'
	end

	def reduce_title( title)
		if m = /^(.*) &gt;/.match( title)
			title = m[1]
		end
		title.gsub( '&#39;', "'")
	end
end
