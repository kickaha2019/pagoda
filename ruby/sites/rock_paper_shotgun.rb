require_relative 'default_site'

class RockPaperShotgun < DefaultSite
	def find( scanner)
		path = scanner.cache + "/rock_paper_shotgun.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			page, urls, old_count = 1, {}, -1

			while (old_count < urls.size) || (page < 84)
				old_count = urls.size

				raw_url = 'https://www.rockpapershotgun.com/reviews'
				raw_url = raw_url + "?page=#{page}" if page > 1
				raw = scanner.http_get raw_url
				#File.open( '/Users/peter/temp/rock_paper_shotgun.html', 'w') {|io| io.print raw}
				#raw = IO.read( '/Users/peter/temp/rock_paper_shotgun.html')

				raw.split( 'href="').each do |line|
					if m = /^(https:\/\/www\.rockpapershotgun[^"]*review)"\s*>([^<]*review[^<]*)<\/a/.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						text = text.sub( /\?$/, '')
						urls[m[1]] = text.strip
					end
				end

				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.suggest_link( name, url)
		end
	end

	def get_game_description( page)
		page
	end

	def name
		'RockPaperShotgun'
  end
end
