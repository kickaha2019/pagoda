class AdventureGamers
	def find( scanner)
		scanner.twitter_feed_links( 'adventuregamers') do |text, link|
			if /Root Letter/ =~ text
				p [text, link]
			end
			if /^https:\/\/adventuregamers\.com\/articles\/view\/.*$/ =~ link
				scanner.add_link( '', link)
			else
				0
			end
		end
	end
end
