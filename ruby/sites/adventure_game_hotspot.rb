require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	def filter( pagoda, link, page, rec)
		title = rec[:title].strip
		if m1 = /^(.*) Adventure Game Hotspot/.match( title)
			rec[:title] = m1[1].strip.sub( / -$/, '')
			true
		else
			rec[:valid] = false
			false
		end
	end

	def findReviews( scanner)
		scanner.html_links( 'https://adventuregamehotspot.com/comments/reviews/') do |link|
			if /com\/\d\d\d\d/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end

	def findWalkthroughs( scanner)
		scanner.html_links( 'https://adventuregamehotspot.com/hints/') do |link|
			if /com\/\d\d\d\d/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end

	def get_game_description( page)
		elide_nav_blocks( elide_script_blocks page)
	end

	def name
		'Adventure Game Hotspot'
	end
end
