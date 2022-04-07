class MysteryManor
	def check_child_link( url, text, anchor)
	end

	def find( scanner)
		scanner.html_links( 'https://mysterymanor.net/conservatory.htm') do |link|
			if /^review/ =~ link
				scanner.add_link( '', 'https://mysterymanor.net/' + link)
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
