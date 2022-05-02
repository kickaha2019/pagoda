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

	def name
		'Just Adventure'
	end
end
