require_relative 'default_site'

class GameBoomers < DefaultSite
	def findReviews( scanner)
		scanner.html_links( 'https://www.gameboomers.com/reviews.html') do |link|
			if /^http(|s):\/\/(www\.|)gameboomers\.com\/reviews\/.*$/ =~ link
				scanner.add_link( '', link.sub( /^https/, 'http').gsub( /\s/, ''))
			else
				0
			end
		end
	end

	def findWalkthroughs( scanner)
		scanner.html_links( 'https://www.gameboomers.com/walkthroughs.html') do |link|
      added = 0
			if /Walkthroughs\/.*walkthroughs\.html$/ =~ link
				added += scanner.html_links( link) do |link2|
					if /^http(|s):\/\/(www\.|)gameboomers\.com\/wtcheats\/.*$/ =~ link2
						scanner.add_link( '', link2.sub( /^https/, 'http').gsub( /\s/, ''))
					else
						0
					end
				end
			end
			added
		end
	end

	def get_game_description( page)
		page
	end

	def get_link_year( page)
		if m = /design copyright  (\d\d\d\d)/.match( page)
			m[1]
		else
			nil
		end
	end

	def name
		'GameBoomers'
	end
end
