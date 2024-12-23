require_relative '../common'
require_relative 'default_site'

class AdventureGamers < DefaultSite
	include Common

	def correlate_url( url) # https://adventuregamers.com/games/view/23987
		if m = %r{^(https://adventuregamers.com/games/view/\d+)$}.match( url)
			return "Adventure Gamers", "Database", m[1]
		end
		return nil, nil, nil
	end

	def find( scanner)
		scanner.html_anchors( 'https://adventuregamers.com/articles/reviews') do |link, label|
			if /^https:\/\/adventuregamers\.com\/articles\/view\/.*$/ =~ link
				scanner.add_link( label, link.split('?')[0])
			elsif /^\/articles\/view\/.*$/ =~ link
				scanner.add_link( label, 'https://adventuregamers.com' + link.split('?')[0])
			else
				0
			end
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
		# to_add.each do |link|
		# 	page = scanner.read_cached_page link
		# 	if m = /<a href="(\/games\/[^"]*)"[^>]*>Full Game Details</.match(page)
		# 		if scanner.add_link('', BASE + m[1]) > 0
		# 			scanner.bind(BASE + m[1], link.collation.id)
		# 			added += 1
		# 		end
		# 	end
		# end

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
