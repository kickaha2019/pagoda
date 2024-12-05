require_relative 'default_site'

class JustAdventure < DefaultSite
	def find_reviews( scanner)
		page = 1
		url  = 'https://www.justadventure.com/category/reviews/'
		while page
			last, page = page, nil
			scanner.html_anchors(url) do |href, label|
				if m = %r{^https://www.justadventure.com/category/reviews/page/(\d+)/}.match(href)
					if m[1].to_i == (last+1)
						page = m[1].to_i
						url = "https://www.justadventure.com/category/reviews/page/#{page}/"
					end
				end

				if (%r{^https://www.justadventure.com/\d\d\d\d/\d+/\d+/} =~ href) &&
					(/Review/ =~ label)
					scanner.add_link( label, href)
				else
					0
				end
			end
		end
	end

	def find_walkthroughs( scanner)
		page = 1
		url  = 'https://www.justadventure.com/category/walkthrough/'
		while page
			last, page = page, nil
			scanner.html_anchors(url) do |href, label|
				if m = %r{^https://www.justadventure.com/category/walkthrough/page/(\d+)/}.match(href)
					if m[1].to_i == (last+1)
						page = m[1].to_i
						url = "https://www.justadventure.com/category/walkthrough/page/#{page}/"
					end
				end

				if (%r{^https://www.justadventure.com/\d\d\d\d/\d+/\d+/} =~ href) &&
					(/Walkthrough/ =~ label)
					scanner.add_link( label, href)
				else
					0
				end
			end
		end
	end

	def reduce_title(title)
		if m = /^(.*)- JustAdventure/.match(title.strip)
			title = m[1].strip
		end

		if m = /^(.*) Review$/.match(title.strip)
			title = m[1].strip
		end

		if m = /^(.*) Walkthrough$/.match(title.strip)
			title = m[1].strip
		end

		if m = /^(.*) - Review \d of \d$/.match(title.strip)
			title = m[1].strip
		end

		title
	end

	def name
		'Just Adventure'
	end

	def year_tolerance
		100
	end

	def post_load(pagoda, url, page)
		nodes    = Nodes.parse( page)

		{}.tap do |digest|
			nodes.css('h1.entry-title') do |title|
				digest['title'] = reduce_title(force_ascii(title.text.strip))
			end

			nodes.css('time.entry-date') do |atime|
				if m = /^(\d\d\d\d)-/.match(atime['datetime'])
					digest['link_year'] = m[1].to_i
				end
			end
		end
	end
end
