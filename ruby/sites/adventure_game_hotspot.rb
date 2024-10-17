require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	BASE = 'https://adventuregamehotspot.com'
	ASPECT_MAP = {
		'Perspective' =>
			{'Third-Person' => '3rd person'}
	}.freeze

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
		have_database = {}
		scanner.get_links_for(name,'Database') do |link|
			if collation = link.collation
				have_database[collation.id] = true
			end
		end

		to_add = []
		scanner.get_links_for(name,'Review') do |link|
			if (collation = link.collation) && (! have_database[collation.id])
				to_add << link
			end
		end

		added = 0
		to_add.each do |link|
			page = scanner.read_cached_page link
			if m = /<a href="(\/game\/[^"]*)">View in Database</.match(page)
				if scanner.add_link('', BASE + m[1]) > 0
					scanner.bind(BASE + m[1], link.collation.id)
					added += 1
				end
			end
		end

		added
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

	def get_aspects(pagoda, page)
		Nodes.parse( page).css('div.game-details th') do |th|
			if map = ASPECT_MAP[th.text]
				th.parent.css('a').each do |value|
					aspect = map[value.text] || "#{th.text}: #{value.text}"
					yield aspect unless aspect.empty?
				end
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
				atime = th.parent.css('a time').first
				if atime
					time = atime['datetime']
					if m = /^(\d\d\d\d)-/.match(time)
						game[:year] = m[1].to_i
					end
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
		if m = /^(.*\S)\s*\|$/.match(title)
			title = m[1]
		end

		if m = /^(.*) review$/.match(title)
			title = m[1]
		end

		title
	end
end
