require_relative 'default_site'

class TapRepeatedly < DefaultSite
	def filter( pagoda, link, page, rec)
		if m = /^(.*)Review - Tap-Repeatedly/.match( rec[:title].strip)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def name
		'Tap Repeatedly'
	end
end
