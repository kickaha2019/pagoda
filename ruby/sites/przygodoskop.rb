require_relative 'default_site'

class Przygodoskop < DefaultSite
	def reduce_title(title)
		if m = /^(.*) - (recenzja|solucja) -/.match( title.strip)
			m[1]
		else
			title
		end
	end

	def name
		'Przygodoskop (P)'
	end
end
