require_relative 'default_site'

class GameBoomers < DefaultSite
	def find_reviews( scanner)
		added  = 0
		scanner.refresh('game_boomers_reviews') do |found|
			scanner.html_anchors( 'https://www.gameboomers.com/reviews.html') do |link, label|
				if /^http(|s):\/\/(www\.|)gameboomers\.com\/reviews\/.*$/ =~ link
					found[link.sub( /^https/, 'http').gsub( /\s/, '')] = label
				end
				0
			end
		end.each_pair do |url, label|
			added += scanner.add_link( label, url)
		end
		added
	end

	def find_walkthroughs( scanner)
		added  = 0
		scanner.refresh('game_boomers_walkthroughs') do |found|
			scanner.html_anchors( 'https://www.gameboomers.com/walkthroughs.html') do |link, _|
				if /Walkthroughs\/.*walkthroughs\.html$/ =~ link
					scanner.html_anchors( link) do |link2, label2|
						if /^http(|s):\/\/(www\.|)gameboomers\.com\/wtcheats\/.*$/ =~ link2
							found[link2.sub( /^https/, 'http').gsub( /\s/, '')] = label2
						end
						0
					end
				end
				0
			end
		end.each_pair do |url, label|
			added += scanner.add_link( label, url)
		end
		added
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
