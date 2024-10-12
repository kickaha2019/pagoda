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

	def find_database( scanner)
		to_scan, next_page = BASE + '/database', 1
		while to_scan && (next_page < 2000)
			scan, to_scan = to_scan, nil
			next_page += 1

			scanner.html_links( scan) do |link|
				if /^\/game\/\d+\// =~ link
					if /#/ =~ link
						0
					else
						scanner.add_link( '', BASE+ link)
					end
				elsif m = /^\?r=0.*p=(\d+)$/.match(link)
					if m[1].to_i == next_page
						to_scan = BASE + '/database' + link
					end
					0
				else
					0
				end
			end
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

	def get_game_details( url, page, game)
		Nodes.parse( page).css('div.game-details th') do |th|
			if th.text == 'Developer'
				game[:developer] = th.parent.css('a').first.text.strip
			end
			if th.text == 'Publisher'
				game[:publisher] = th.parent.css('a').first.text.strip
			end
			if th.text == 'Release'
				time = th.parent.css('a time').first['datetime']
				if m = /^(\d\d\d\d)-/.match(time)
					game[:year] = m[1].to_i
				end
			end
		end
	end

	def get_game_description( page)
		elide_nav_blocks( elide_script_blocks page)
	end

	def get_link_year( page)
		if m = /"datePublished":"(\d\d\d\d)-\d\d-\d\d"/.match( page)
			m[1]
		else
			nil
		end
	end

	def name
		'Adventure Game Hotspot'
	end

	def reduce_title( title)
		if m = /^(.*) review \|$/.match(title)
			m[1]
		else
			title
		end
	end
end
