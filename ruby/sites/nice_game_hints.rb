require_relative 'default_site'

class NiceGameHints < DefaultSite
	def find( scanner)
		count = 0

		raw = scanner.browser_get "https://www.nicegamehints.com/all-games"
		Nodes.parse( raw).css( 'h2') do |anchor|
			[anchor.text]
		end.parent(3).css('a') do |element, text|
			if / Read the hints / =~ element.text
				scanner.add_link( text, 'https://www.nicegamehints.com' + element['href'])
				count += 1
			end
		end

		count
	end

	def name
		'Nice Game Hints'
	end
end
