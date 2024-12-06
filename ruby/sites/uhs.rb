require_relative 'default_site'

class Uhs < DefaultSite
	def reduce_title(title)
		title = title.strip

		if m = /^(.*)Hints from UHS/.match( title)
			m[1].strip
		elsif m1 = /^UHS:\s+(.*)\s+Review$/.match( title)
			m1[1].strip
		else
			title
		end
	end

	def name
		'UHS'
	end
end
