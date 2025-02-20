require_relative 'default_site'

class NiceGameHints < DefaultSite
	def find( scanner, _)
		raw = scanner.browser_get "https://www.nicegamehints.com/all-games"
		Nodes.parse( raw).css( 'h2') do |anchor|
			[anchor.text]
		end.parent(3).css('a') do |element, text|
			if / Read the hints / =~ element.text
				scanner.add_link( text, 'https://www.nicegamehints.com' + element['href'])
			end
		end
	end

	def name
		'Nice Game Hints'
	end

	def reduce_title(title)
		if m = /^(.*\S)\s*| Nice Game Hints$/.match(title.strip)
			title = m[1].strip
		end

		if m = /^(.*\S)\s*| \d+ low-spoiler guides$/.match(title.strip)
			title = m[1].strip
		end

		title
	end
end
