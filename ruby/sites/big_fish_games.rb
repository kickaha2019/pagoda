require_relative 'default_site'

class BigFishGames < DefaultSite
	def validate_page(url,digest)
		if digest['title'] == 'Store'
			'Deleted link'
		else
			nil
		end
	end

	def full( scanner)
		full1( scanner, 'pc-adventure-games') +
		full1( scanner, 'pc-hidden-object-adventure-games')
	end

	def full1( scanner, type)
		base       = 'https://www.bigfishgames.com/us/en/games/'
		match      = Regexp.new( '^' + base + '\d+/')
		url        = base + "genres/#{type}.html?page="
		found      = 0
		page       = 0
		last_found = -1
		added      = 0

		while last_found < found
			last_found =  found
			page       += 1
			added      += scanner.html_anchors( url + page.to_s) do |link, label|
				if match =~ link
					found += 1
					scanner.add_link( label, link.split('?')[0])
				else
					0
				end
			end
		end

		added
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
