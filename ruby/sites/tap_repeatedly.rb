require_relative 'default_site'

class TapRepeatedly < DefaultSite
	def reduce_title(title)
		if m = /^(.*)Review - Tap-Repeatedly/.match( title.strip)
			m[1].strip
		else
			title
		end
	end

	def name
		'Tap Repeatedly'
	end

	def static?
		true
	end
end
