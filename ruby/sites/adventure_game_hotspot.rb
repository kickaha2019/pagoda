require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	BASE = 'https://adventuregamehotspot.com'

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
		scanner.html_links( BASE + '/reviews/') do |link|
			if /^\/review\/\d+\// =~ link
				if /#/ =~ link
					0
				else
					scanner.add_link( '', BASE+ link)
				end
			else
				0
			end
		end
	end

	def findWalkthroughs( scanner)
		scanner.html_links( BASE + '/walkthroughs/') do |link|
			if /^\/walkthrough\/\d+\// =~ link
				if /#/ =~ link
					0
				else
					scanner.add_link( '', BASE+ link)
				end
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
