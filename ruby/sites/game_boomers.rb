class GameBoomers
	def find( scanner)
		scanner.html_links( 'https://www.gameboomers.com/') do |link|
			if /^https:\/\/www.gameboomers.com\/reviews\/.*$/ =~ link
				scanner.add_link( '', link)
			end
		end
	end
end
