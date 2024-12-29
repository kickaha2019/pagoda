require_relative '../common'
require_relative 'default_site'

class AdventureGamers < DefaultSite
	include Common
	BASE = 'https://adventuregamers.com'

	def correlate_url( url) # https://adventuregamers.com/games/view/23987
		if m = %r{^(https://adventuregamers.com/games/view/\d+)$}.match( url)
			return "Adventure Gamers", "Database", m[1]
		end
		return nil, nil, nil
	end

	def find_database( scanner)
		added = 0
		page  = 1
		url   = BASE + '/games/adventure/all'

		while page
			last, page = page, nil
			added += scanner.html_anchors(url) do |href, label|
				if label == (last+1).to_s
					page = last + 1
					url  = BASE + href
					0
				elsif /^ / =~ label
					0
				elsif /\t/ =~ label
					0
				elsif m = %r{^(/games/view/\d+)$}.match(href)
					scanner.add_link( label, BASE + m[1])
				else
					0
				end
			end
		end

		added
	end

	def find_reviews( scanner)
		added = 0
		page  = 1
		url   = BASE + '/articles/reviews'

		while page
			last, page = page, nil
			added += scanner.html_anchors(url) do |href, label|
				if label == (last+1).to_s
					page = last + 1
					url  = href
					0
				elsif ['','Genre Introduction','Top 100 All-Time'].include? label
					0
				elsif m = %r{^(/articles/view/.*)$}.match(href)
					scanner.add_link( label, BASE + m[1].split('?')[0])
				else
					0
				end
			end
		end

		added
	end

	def reduce_title(title)
		title = title.strip

		if m = /^(.*) \| Adventure Gamers$/.match( title)
			title = m[1].strip
		end

		if m1 = /^(.*) review$/.match( title)
			title = m1[1].strip
		elsif m = /^(.*) Game details$/.match( title)
			title = m[1].strip
		end

		if m = /^(.*)-$/.match( title)
			m[1].strip
		else
			title
		end
	end

  def name
    'Adventure Gamers'
  end

	def post_load(pagoda, url, page)
		digest = super
		return digest unless %r{\.com/games/view/\d+$} =~ url

		nodes = Nodes.parse( page)

		nodes.css('strong') do |header|
			[header.text.strip]
		end.parent.css('span.cat_label_item span') do |release, header|
			if header == 'Releases:'
				if m = / (\d\d\d\d)$/.match(release.text.strip)
					digest['year'] = m[1].to_i
				end
			end
		end

		digest['unreleased'] = true unless digest['year'].nil?

		digest['tags'] = ['Adventure']
		['Genre','Presentation','Perspective','Graphic Style','Gameplay',
		 'Control','Theme'].each do |label|
			get_anchors( nodes, label) do |anchor|
				digest['tags'] << anchor.text.strip
			end
		end

		digest
	end

	def get_anchors(nodes, type)
		nodes.css('table.game_info_table td strong') do |title|
			[title.text.strip]
		end.parent(2).css('td:nth-child(2)') do |field, header|
			if header == type
				yield field
			end
		end
	end

	def year_tolerance
		1
	end
end
