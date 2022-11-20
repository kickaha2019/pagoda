require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	def findReviews( scanner)
		scanner.html_links( 'https://adventuregamehotspot.com/comments/reviews/') do |link|
			if /\d\d\d\d/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end

	def findWalkthroughs( scanner)
		scanner.html_links( 'https://adventuregamehotspot.com/hints/') do |link|
			if /\d\d\d\d/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'Adventure Game Hotspot'
	end
end
