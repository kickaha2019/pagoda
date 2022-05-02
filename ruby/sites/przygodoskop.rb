require_relative 'default_site'

class Przygodoskop < DefaultSite
	def filter( pagoda, link, page, rec)
		if m = /^(.*) - (recenzja|solucja) -/.match( rec[:title].strip)
			rec[:title] = m[1]
			true
		else
			rec[:valid] = false
			false
		end
	end

	def name
		'Przygodoskop (P)'
	end
end
