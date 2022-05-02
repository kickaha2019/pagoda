require_relative 'default_site'

class Uhs < DefaultSite
	def filter( pagoda, link, page, rec)
		if m = /^(.*)Hints from UHS/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_game_description( page)
		''
	end

	def name
		'UHS'
	end
end
