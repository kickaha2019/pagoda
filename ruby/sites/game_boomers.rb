require_relative 'default_site'

class GameBoomers < DefaultSite
	def find( scanner)
		scanner.html_links( 'https://www.gameboomers.com/') do |link|
			if /^https:\/\/www.gameboomers.com\/reviews\/.*$/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end
end
