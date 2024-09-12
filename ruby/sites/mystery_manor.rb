require_relative 'default_site'

class MysteryManor < DefaultSite
	def filter( pagoda, link, page, rec)
		rec[:title] = reduce_title( rec[:title])
	end

	def find_reviews( scanner)
		scanner.html_links( 'https://mysterymanor.net/conservatory.htm') do |link|
			if /^review/ =~ link
				scanner.add_link( '', 'https://mysterymanor.net/' + link)
			else
				0
			end
		end
	end

	def find_walkthroughs( scanner)
		scanner.html_links( 'https://mysterymanor.net/walkthroughs.htm') do |link|
			if /^walkthroughs/ =~ link
				scanner.add_link( '', 'https://mysterymanor.net/' + link)
			else
				0
			end
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'Mystery Manor'
	end

	def reduce_title( title)
		if m = /^Mystery Manor Adventure(.*)$/.match( title)
			title = m[1]
		end
		if m = /^(.+) Walkthrough$/.match( title)
			title = m[1]
		end
		title.strip
	end
end
