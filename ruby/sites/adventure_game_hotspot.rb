require_relative 'default_site'

class AdventureGameHotspot < DefaultSite
	BASE = 'https://adventuregamehotspot.com'

	def find_database( scanner)
		added = 0
		page  = 1
		url   = BASE + '/database'

		while page
			last, page = page, nil
			added += scanner.html_anchors(url) do |href, label|
				if m = %r{^\?p=(\d+)$}.match(href)
					if m[1].to_i == (last+1)
						page = m[1].to_i
						url = BASE + '/database' + href
					end
				end

				if (m = %r{^(/game/.*$)}.match(href)) && (! (/^</ =~ label))
					scanner.add_link( label, BASE + m[1])
				else
					0
				end
			end
		end

		added
	end

	def findReviews( scanner)
		scanner.html_anchors(BASE + '/reviews/') do |link, label|
			if /^\/review\/\d+\// =~ link
				if /#/ =~ link
					0
				else
					scanner.add_link( label, BASE+ link)
				end
			else
				0
			end
		end
	end

	def findWalkthroughs( scanner)
		scanner.html_anchors(BASE + '/walkthroughs/') do |link, label|
			if /^\/walkthrough\/\d+\// =~ link
				if /#/ =~ link
					0
				else
					scanner.add_link( label, BASE+ link)
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
