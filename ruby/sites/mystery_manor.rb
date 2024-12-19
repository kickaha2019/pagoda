require_relative 'default_site'

class MysteryManor < DefaultSite
	def find_reviews( scanner)
		scanner.html_anchors( 'https://mysterymanor.net/conservatory.htm') do |link, label|
			if /^review/ =~ link
				scanner.add_link( label, 'https://mysterymanor.net/' + link)
			else
				0
			end
		end
	end

	def find_walkthroughs( scanner)
		scanner.html_anchors( 'https://mysterymanor.net/walkthroughs.htm') do |link, label|
			if /^walkthroughs/ =~ link
				scanner.add_link( label, 'https://mysterymanor.net/' + link)
			else
				0
			end
		end
	end

	def name
		'Mystery Manor'
	end

	def reduce_title( title)
		if m = /^Mystery Manor Adventure(.*)$/.match( title)
			title = m[1]
		end
		if m = /^(.+) Walkthrough$/.match( title)
			title = m[1]
		end
		title.strip
	end
end
