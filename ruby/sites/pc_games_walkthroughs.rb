require_relative 'default_site'

class PcGamesWalkthroughs < DefaultSite
	def find( scanner)
		scanner.html_links( 'http://www.pcgameswalkthroughs.nl/walkthroughs_english.htm') do |link|
			if /^Walkthroughs\// =~ link
				scanner.add_link( '', 'http://www.pcgameswalkthroughs.nl/' + link)
			else
				0
			end
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'PC Games Walkthroughs'
	end
end
