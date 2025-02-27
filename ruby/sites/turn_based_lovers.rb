require_relative 'default_site'

class TurnBasedLovers < DefaultSite
	def find_reviews( scanner, _)
		page    = 1
		url     = 'https://turnbasedlovers.com/-/review/'
		added   = 1
		scanned = 0

		while page && (added > 0)
			last, page, added = page, nil, 0
			scanned += 1

			scanner.html_anchors(url) do |href, label|
				if m = %r{^https://turnbasedlovers.com/-/review/page/(\d+)/}.match(href)
					if m[1].to_i == (last+1)
						page = m[1].to_i
						url = "https://turnbasedlovers.com/-/review/page/#{page}/"
					end
				end

				if (%r{^https://turnbasedlovers.com/review/} =~ href) &&
					(/ Review($|:)/ =~ label)
					added += scanner.add_link( label, href)
				end
			end
		end

		"#{scanned} scans"
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

		if m = /^(.*\S)\s*\? Review\s*$/.match(title)
			title = m[1]
		end

		if m = /^(.*\S)\s*-\s*$/.match(title)
			title = m[1]
		end

		title
	end
end
