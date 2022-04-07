class GameBoomers
	def check_child_link( url, text, anchor)
	end

	def find( scanner)
		scanner.html_links( 'https://www.gameboomers.com/') do |link|
			if /^https:\/\/www.gameboomers.com\/reviews\/.*$/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end

	def get_game_description( page)
		page
	end

	def get_game_details( url, page, game)
	end
end
