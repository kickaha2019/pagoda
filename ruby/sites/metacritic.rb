require_relative '../nodes'
require_relative 'default_site'

class Metacritic < DefaultSite
	def find( scanner)
		path = scanner.cache + "/metacritic.json"

		if File.exist?( path)
			JSON.parse( IO.read( path)).each_pair do |url, name|
				scanner.suggest_link( name, url)
			end
		end
	end

	def get_game_description( page)
		page
	end

	def get_game_year( pagoda, link, page, rec)
		if g = link.collation
			Nodes.parse( page).css( 'li.full_review a') do |anchor|
				[anchor['href']]
			end.parent(5).css( 'div.source a') do |anchor, href|
				review = pagoda.link( href)
				unless review
					pagoda.add_link( anchor.text, 'Review', link.orig_title, href, 'Y')
					review = pagoda.link( href)
				end
				unless review.bound?
					review.bind( g.id)
				end
			end
		end
	end

	def incremental( scanner)
		path  = scanner.cache + "/metacritic.json"
		found = File.exist?( path) ? JSON.parse( IO.read( path)) : {}

		path_md  = scanner.cache + "/metacritic_metadata.json"
		metadata = Hash.new {|h,k| h[k] = -1}
		if File.exist?( path_md)
			JSON.parse( IO.read( path_md)).each_pair do |k,v|
				metadata[k] = v
			end
		end

		incremental_section( scanner, 'adventure/pc',     metadata, found)
		incremental_section( scanner, 'adventure/ios',    metadata, found)
		incremental_section( scanner, 'puzzle/pc',        metadata, found)
		incremental_section( scanner, 'puzzle/ios',       metadata, found)
		incremental_section( scanner, 'role-playing/pc',  metadata, found)
		incremental_section( scanner, 'role-playing/ios', metadata, found)
		incremental_section( scanner, 'turn-based/pc',    metadata, found)
		incremental_section( scanner, 'turn-based/ios',   metadata, found)

		File.open( path,    'w') {|io| io.print JSON.generate( found)}
		File.open( path_md, 'w') {|io| io.print JSON.generate( metadata)}
		0
	end

	def incremental_section( scanner, section, metadata, found)
		page  = metadata[section] + 1
		count = 0

		raw_url = "https://www.metacritic.com/browse/games/genre/date/#{section}"
		raw_url = raw_url + "?page=#{page}" if page > 0
		raw     = scanner.http_get raw_url

		#File.open( '/Users/peter/temp/metacritic.html', 'w') {|io| io.print raw}
		#raw = IO.read( '/Users/peter/temp/rock_paper_shotgun.html')

		Nodes.parse( raw).css( 'a') do |anchor|
			if %r{^/game/} =~ anchor['href']
				[anchor['href']]
			end
		end.css('img') do |element, href|
			found['https://www.metacritic.com' + href] = element['alt']
			count += 1
		end

		metadata[section] = (count > 0) ? page : -1
	end

	def name
		'Metacritic'
  end
end
