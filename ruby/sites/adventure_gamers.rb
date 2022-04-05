require 'json'
require_relative '../common'

class AdventureGamers
	include Common

	def extract_json( html)
		inside, text = false, []

		html.split("\n").each do |line|
			#p line if /script type="application\// =~ line
			if /<script type="application\/ld\+json">/ =~ line
				inside, text = true, []
			elsif inside
				if m=/^(.*)<\/script>/.match( line)
					text = text.join( ' ') + ' ' + m[1]
					begin
						json = JSON.parse( text)
						return json if json['review']
						inside, text = false, []
					rescue
						File.open( '/tmp/bad.json', 'w') {|io| io.puts text}
						return false
					end
				else
					text << line.chomp
				end
			end
		end

		false
	end

	def find( scanner)
		scanner.twitter_feed_links( 'adventuregamers') do |text, link|
			if /^https:\/\/adventuregamers\.com\/articles\/view\/.*$/ =~ link
				scanner.add_link( '', link.split('?')[0])
			else
				0
			end
		end
	end

	def get_game_description( page)
		if json = extract_json( page)
			json['review']['reviewBody']
		else
			page
		end
	end

	def get_game_details( url, page, game)
		#p ['Adventure Gamers:get_game_details1', url]
		url = nil
		page.split("\n").each do |line|
			if m = /"gtin":"(.*)"/.match(line)
				url = m[1]
				break
			end
			if m1 = /<a href="(https:\/\/adventuregamers\.com\/games\/view\/\d+)">([^<]*)<\/a>/.match( line)
				if m1[2] == game[:name]
					url = m1[1]
					break
				end
			end
		end
		return unless url

		#p ['Adventure Gamers:get_game_details2', url]
		page = http_get( url)

		if after_developer = page.split('Developer:')[1]
			if span = after_developer.split( '<span>')[1]
				game[:developer] = span.split('<')[0]
			end
			if after_release = after_developer.split( 'Releases:')[1]
				spans = after_release.split( '</span>')
				if m2 = /(\d\d\d\d)$/m.match( spans[0])
					game[:year] = m2[1]
				end
				if spans[1]
					if m3 = /by ([^<]*)$/.match( spans[1])
						game[:publisher] = m3[1].strip
					end
				end
			end
		end
	end
end
