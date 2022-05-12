require_relative 'default_site'

class Uhs < DefaultSite
	def filter( pagoda, link, page, rec)
		title = rec[:title].strip

		if m = /^(.*)Hints from UHS/.match( title)
			rec[:title] = m[1].strip
			true
		elsif m1 = /^UHS:\s+(.*)\s+Review$/.match( title)
			rec[:title] = m1[1].strip
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
