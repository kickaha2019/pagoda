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

	def find_database( scanner)
		have_database = {}
		scanner.get_links_for(name,'Database') do |link|
			if collation = link.collation
				have_database[collation.id] = true
			end
		end

		to_add = []
		scanner.get_links_for(name,'Review') do |link|
			if (collation = link.collation) && (! have_database[collation.id])
				to_add << link
			end
		end

		added = 0
		# to_add.each do |link|
		# 	page = scanner.read_cached_page link
		# 	if m = /<a href="(\/games\/[^"]*)"[^>]*>Full Game Details</.match(page)
		# 		if scanner.add_link('', BASE + m[1]) > 0
		# 			scanner.bind(BASE + m[1], link.collation.id)
		# 			added += 1
		# 		end
		# 	end
		# end

		added
	end

	def reduce_title(title)
		title = title.strip
		if m1 = /^(.*)(-|) review \| Adventure Gamers/.match( title)
			m1[1].strip
		elsif m = /^(.*)(-|) \| Adventure Gamers/.match( title)
			m[1].strip
		else
			title
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

	def get_game_details1( url, page, game)
		begin
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
