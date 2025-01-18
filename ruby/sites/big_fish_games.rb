require_relative 'default_site'

class BigFishGames < DefaultSite
	def validate_page(url,digest)
		if digest['title'] == 'Store'
			'Deleted link'
		else
			nil
		end
	end

	def find_adventures(scanner,_)
		find( scanner, 'pc-adventure-games')
	end

	def find_hogs(scanner,_)
		find( scanner, 'pc-hidden-object-games')
	end

	def find_hopa(scanner,_)
		find( scanner, 'pc-hidden-object-adventure-games')
	end

	def find_puzzles(scanner,_)
		find( scanner, 'pc-puzzle-games')
	end

	def find( scanner, type)
		base       = 'https://www.bigfishgames.com/us/en/games/'
		match      = Regexp.new( '^' + base + '\d+/')
		url        = base + "genres/#{type}.html?page="
		found      = 0
		page       = 0
		last_found = -1

		while last_found < found
			last_found =  found
			page       += 1
			scanner.html_anchors( url + page.to_s) do |link, label|
				if match =~ link
					found += 1
					scanner.add_link(label, link.split('?')[0])
				end
			end
		end
	end

	def name
		'Big Fish Games'
	end

	def reduce_title( title)
		if m = /^(.*) &gt;/.match( title)
			title = m[1]
		end
		title.gsub( '&#39;', "'")
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			nodes.css('div.productBreadcrumb__root') do |breadcrumbs|
				digest['title'] = breadcrumbs.text.split('>')[-1].strip
			end
			nodes.css('div.productFullDetail__descriptionContent') do |desc|
				digest['description'] = desc.text.strip
			end
		end
	end
end
