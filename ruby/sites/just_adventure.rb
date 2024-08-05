require_relative 'default_site'

class JustAdventure < DefaultSite
	def filter( pagoda, link, page, rec)
		if m = /^(.*)- JustAdventure/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_link_year( page)
		if m = /dateCreated">[A-Za-z0-9 ]*, (\d\d\d\d)<\/time>/.match( page)
			m[1]
		else
			nil
		end
	end

	def name
		'Just Adventure'
	end

	def year_tolerance
		100
	end
end
