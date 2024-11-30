require_relative 'default_site'

class BrassLantern < DefaultSite
	def name
		'Brass Lantern'
	end

	def year_tolerance
		10
	end

	def post_load(pagoda, url, page)
		digest = super

		if m = /This article copyright &copy; (\d\d\d\d),/.match( page)
			digest['link_year'] = m[1].to_i
		end

		digest
	end

	def reduce_title( title)
		if m = /^(.*) Review\s*$/.match(title)
			title = m[1]
		end

		if m = /^Brass Lantern\s*(.*)$/.match( title.strip)
			m[1]
		else
			title
		end
	end
end
