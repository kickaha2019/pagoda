require_relative 'default_site'

class BrassLantern < DefaultSite
	def get_link_year( page)
		if m = /This article copyright &copy; (\d\d\d\d),/.match( page)
			m[1]
		else
			nil
		end
	end

	def name
		'Brass Lantern'
	end

	def year_tolerance
		10
	end
end
