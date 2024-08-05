require_relative 'default_site'

class AdventureClassicGaming < DefaultSite
	def filter( pagoda, link, page, rec)
		if m = /^(.*)- (Review|Cheat) - Adventure Classic Gaming/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_link_year( page)
		if m = /First posted on \d+ \w+ (\d\d\d\d)/.match( page)
			m[1]
		else
			nil
		end
	end

	def name
		'Adventure Classic Gaming'
	end

	def year_tolerance
		50
	end
end
