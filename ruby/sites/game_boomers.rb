require_relative 'default_site'

class GameBoomers < DefaultSite
	def find_reviews( scanner)
		scanner.refresh do
			scanner.html_anchors( 'https://www.gameboomers.com/reviews.html') do |link, label|
				if /^http(|s):\/\/(www\.|)gameboomers\.com\/reviews\/.*$/ =~ link
					scanner.add_link( label, link.sub( /^https/, 'http').gsub( /\s/, ''))
				end
			end
		end
	end

	def find_walkthroughs( scanner)
		scanner.refresh(yday = scanner.yday) do
			pages = []
			scanner.html_anchors( 'https://www.gameboomers.com/walkthroughs.html') do |link, _|
				if /Walkthroughs\/.*walkthroughs\.html$/ =~ link
					pages << link
				end
			end

			scanner.html_anchors( pages[ yday % pages.size]) do |link2, label2|
				if /^http(|s):\/\/(www\.|)gameboomers\.com\/wtcheats\/.*$/ =~ link2
					scanner.add_link( label2, link2.sub( /^https/, 'http').gsub( /\s/, ''))
				end
			end
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
