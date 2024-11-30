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

	def name
		'GameBoomers'
	end

	def post_load(pagoda, url, page)
		digest = super

		if m = />design copyright[^<]*(\d\d\d\d)\s*</m.match( page)
			digest['link_year'] = m[1].to_i
		end

		digest
	end

	def reduce_title( title)
		if m = /^(.*) review\s*$/.match(title)
			title = m[1]
		end

		title
	end
end
