require_relative 'default_site'

class TurnBasedLovers < DefaultSite
	def findReviews( scanner)
		page = 1
		url  = 'https://turnbasedlovers.com/-/review/'
		while page
			last, page = page, nil
			scanner.html_anchors(url) do |href, label|
				if m = %r{^https://turnbasedlovers.com/-/review/page/(\d+)/}.match(href)
					if m[1].to_i == (last+1)
						page = m[1].to_i
						url = "https://turnbasedlovers.com/-/review/page/#{page}/"
					end
				end

				if (%r{^https://turnbasedlovers.com/review/} =~ href) &&
					(/ Review($|:)/ =~ label)
					scanner.add_link( label, href)
				else
					0
				end
			end
		end
	end

	def name
		'Turn Based Lovers'
	end

	def post_load(pagoda, url, page)
		digest = super

		if m = /published" datetime="(\d\d\d\d)-/m.match( page)
			digest['link_year'] = m[1].to_i
		end

		digest
	end

	def reduce_title( title)
		if m = /^(.*) Review - Turn Based Lovers\s*$/.match(title)
			title = m[1]
		end

		title
	end
end
