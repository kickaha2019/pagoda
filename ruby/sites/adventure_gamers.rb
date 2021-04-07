class AdventureGamers
	def complete?( scanner)
		true
	end

	def find( scanner, page, lifetime, url2link)
		return if page > 0
		reviews, walkthroughs = 0, 0

		scanner.twitter_feed_links( 'adventuregamers') do |link|
			if /^https:\/\/adventuregamers.com\/articles\/view\/.*$/ =~ link
				url2link[link] = {site:title, type:'Review', title:'???', url:link, force:true}
				reviews += 1
			elsif /^https:\/\/adventuregamers.com\/walkthrough\/.*$/ =~ link
				url2link[link] = {site:title, type:'Walkthrough', title:'???', url:link, force:true}
				walkthroughs += 1
			end
		end

		puts "... Adventure Gamers: #{reviews} reviews #{walkthroughs} walkthroughs found"
	end

	def title
		'Adventure Gamers'
	end
end
