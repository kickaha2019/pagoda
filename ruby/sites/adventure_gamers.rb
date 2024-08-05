require_relative '../common'
require_relative 'default_site'

class AdventureGamers < DefaultSite
	include Common

	def find( scanner)
		scanner.html_links( 'https://adventuregamers.com/articles/reviews') do |link|
			if /^https:\/\/adventuregamers\.com\/articles\/view\/.*$/ =~ link
				scanner.add_link( '', link.split('?')[0])
			elsif /^\/articles\/view\/.*$/ =~ link
				scanner.add_link( '', 'https://adventuregamers.com' + link.split('?')[0])
			else
				0
			end
		end
	end

	def filter( pagoda, link, page, rec)
		title = rec[:title].strip
		if m1 = /^(.*)(-|) review \| Adventure Gamers/.match( title)
			rec[:title] = m1[1].strip
			true
		elsif m = /^(.*)(-|) \| Adventure Gamers/.match( title)
			rec[:title] = m[1].strip
			true
		else
			rec[:valid] = false
			false
		end
	end

	def get_game_description( page)
		inside, text = false, []
		page.split( "\n").each do |line|
			if m = /"reviewBody": "(.*)$/.match( line.chomp)
				#p ['get_game_description1', m[1]]
				inside, text = true, [m[1]]
			elsif inside && (m1 = /^([^"]*)"/.match( line))
				text << m1[1]
				return text.join( ' ')
			elsif inside
				text << line.chomp
			end
		end
		text.join( ' ')
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

		if m = /^(http[^"]*)($|")/.match( url)
			url = m[1]
		else
			return
		end

		#p ['Adventure Gamers:get_game_details2', url[0..100]]
		begin
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
		rescue Exception => bang
			puts "*** #{url}: #{bang.message}"
		end
	end

  def name
    'Adventure Gamers'
  end

	def year_tolerance
		1
	end
end
