require_relative 'default_site'

class AdventureClassicGaming < DefaultSite
	def name
		'Adventure Classic Gaming'
	end

	def year_tolerance
		50
	end

	def reduce_title( title)
		if m = /^(.*)- (Review|Cheat) - Adventure Classic Gaming/.match( title.strip)
			m[1].strip
		else
			title
		end
	end

	def post_load(pagoda, url, page)
		digest = super

		if m = /First posted on \d+ \w+ (\d\d\d\d)/.match( page)
			digest['link_year'] = m[1].to_i
		end

		digest
	end
end
