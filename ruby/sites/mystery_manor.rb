class MysteryManor
	def find( scanner)
		scanner.html_links( 'https://mysterymanor.net/conservatory.htm') do |link|
			if /^review/ =~ link
				scanner.add_link( '', 'https://mysterymanor.net/' + link)
			end
		end
	end
end
