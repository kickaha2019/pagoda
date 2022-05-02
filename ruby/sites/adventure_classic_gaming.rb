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

	def name
		'Adventure Classic Gaming'
	end
end
