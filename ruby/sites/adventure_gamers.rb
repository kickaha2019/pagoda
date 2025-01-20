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

	def find_database( scanner, state)
		run = (/^\d+$/ =~ state) ? state.to_i : 0
		raw = scanner.http_get(BASE + '/games/adventure/all')
		return if raw.nil?
		sections = []
		Nodes.parse( raw).css( 'div.letter a') do |anchor|
			sections << anchor['href']
		end

		page  = 1
		url   = BASE + sections[run % sections.size]

		while page
			last, page = page, nil
			scanner.html_anchors(url) do |href, label|
				if label == (last+1).to_s
					page = last + 1
					url  = BASE + href
				elsif /^ / =~ label
				elsif /\t/ =~ label
				elsif m = %r{^(/games/view/\d+)$}.match(href)
					scanner.add_link(label, BASE + m[1])
				end
			end
		end

		run + 1
	end

	def find_reviews( scanner, _)
		scanner.html_anchors(BASE + '/articles/reviews') do |href, label|
			if ['','Genre Introduction','Top 100 All-Time'].include? label
			elsif m = %r{^(/articles/view/.*)$}.match(href)
				scanner.add_link( label, BASE + m[1].split('?')[0])
			end
		end
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
				begin
					t = Date.parse(release.text.strip).to_time
					if t <= pagoda.now
						digest['year'] = t.year
					end
				rescue StandardError
				end
			end
		end

		digest['unreleased'] = true if digest['year'].nil?

		digest['tags'] = ['Adventure']
		['Genre','Presentation','Perspective','Graphic Style','Gameplay',
		 'Control','Theme'].each do |label|
			get_tags(nodes, label) do |anchor|
				digest['tags'] << anchor
			end
		end

		digest
	end

	def get_tags(nodes, type)
		nodes.css('table.game_info_table td strong') do |title|
			[title.text.strip]
		end.parent(2).css('td:nth-child(2)') do |field, header|
			if header == type
				field.text.split(',').collect {|t| t.strip}.each do |tag|
					yield tag unless tag.empty? || (tag == '-')
				end
			end
		end
	end

	def year_tolerance
		1
	end
end
