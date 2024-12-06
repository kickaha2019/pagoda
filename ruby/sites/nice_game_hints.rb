require_relative 'default_site'

class NiceGameHints < DefaultSite
	def find( scanner)
		count = 0

		raw = scanner.browser_get "https://www.nicegamehints.com/games"
		Nodes.parse( raw).css( 'h4.card-title a') do |anchor|
			[anchor.text]
		end.parent(1).next_element do |element, text|
			scanner.add_link( text, 'https://www.nicegamehints.com' + element['href'])
			count += 1
		end

		count
	end

	def name
		'Nice Game Hints'
	end
end
