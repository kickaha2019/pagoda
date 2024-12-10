require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	BASE = 'https://adventuregamehotspot.com'

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
		# to_add.each do |link|
		# 	page = scanner.read_cached_page link
		# 	if m = /<a href="(\/game\/[^"]*)">View in Database</.match(page)
		# 		if scanner.add_link('', BASE + m[1]) > 0
		# 			scanner.bind(BASE + m[1], link.collation.id)
		# 			added += 1
		# 		end
		# 	end
		# end

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

	def name
		'Adventure Game Hotspot'
	end

	def post_load(pagoda, url, page)
		digest = super
		return digest unless %r{\.com/game/\d+/} =~ url

		nodes = Nodes.parse( page)

		digest['developers'] = []
		get_anchors( nodes, 'Developer') do |anchor|
			digest['developers'] << anchor.text.strip
		end

		digest['publishers'] = []
		get_anchors( nodes, 'Publisher') do |anchor|
			digest['publishers'] << anchor.text.strip
		end

		nodes.css('div.game-details time') do |time|
			begin
				t = Date.parse(time['datetime']).to_time
				if t <= Time.now
					if digest['year'].nil? || digest['year'] > t.year
						digest['year'] = t.year
					end
				end
			rescue StandardError
			end
		end

		digest['unreleased'] = true unless digest['year']

		digest['tags'] = ['Adventure']
		['Genre','Presentation','Perspective','Graphic Style','Gameplay',
		 'Control','Action'].each do |label|
			get_anchors( nodes, label) do |anchor|
				digest['tags'] << anchor.text.strip
			end
		end

		digest
	end

	def get_anchors(nodes, type)
		nodes.css('div.game-details th') do |title|
			[title.text.strip]
		end.parent.css('td a') do |anchor, header|
			if header == type
				yield anchor
			end
		end
	end

	def reduce_title( title)
		if m1 = /^(.*) Adventure Game Hotspot/.match( title)
			title = m1[1].strip.sub( / -$/, '')\
		end

		if m = /^(.*\S)\s*\|$/.match(title)
			title = m[1]
		end

		if m = /^(.*) review$/.match(title)
			title = m[1]
		end

		title
	end
end
