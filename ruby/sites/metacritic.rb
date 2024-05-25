require_relative '../nodes'
require_relative 'default_site'

class Metacritic < DefaultSite
	def correlate_url( url)
		if %r{^https://www.metacritic.com/} =~ url
			return 'Metacritic', 'Reference', url
		else
			return nil, nil, nil
		end
	end

	def find( scanner)
		path = scanner.cache + "/metacritic.json"

		if File.exist?( path)
			JSON.parse( IO.read( path)).each_pair do |url, name|
				scanner.suggest_link( name, url)
			end
		end
	end

	def get_game_details( url, page, game)
		nodes = Nodes.parse( page)

		nodes.css( 'span.u-block') do |span|
			if span.text == 'Initial Release Date:'
				[]
			else
				nil
			end
		end.parent( 1).css( 'span.g-color-gray70') do |span1|
			if m = /(\d\d\d\d)$/.match( span1.text)
				game[:year] = m[1].to_i
			end
		end

		nodes.css( 'span.u-block') do |span|
			if span.text == 'Developer:'
				[]
			else
				nil
			end
		end.parent( 1).css( 'li.u-inline-block') do |li|
			game[:developer] = li.text
		end

		nodes.css( 'span.u-block') do |span|
			if span.text == 'Publisher:'
				[]
			else
				nil
			end
		end.parent( 1).css( 'span.g-color-gray70') do |span1|
			game[:publisher] = span1.text
		end
	end

	def get_game_year( pagoda, link, page, rec)
		if g = link.collation
			notify_bind( pagoda, link, page, g.id)
		end
	end

	def incremental( scanner)
		path  = scanner.cache + "/metacritic.json"
		found = File.exist?( path) ? JSON.parse( IO.read( path)) : {}
		base_url = 'https://www.metacritic.com/browse/game/all/all/all-time/new/?' +
				       'platform=pc&platform=mobile&' +
		           'genre=adventure&genre=rpg&genre=edutainment&' +
				       'genre=turn---based-strategy&genre=puzzle&' +
				       '&releaseYearMin=1910&releaseYearMax=' +
				       Time.now.year.to_s + '&page='

		(1..100).each do |page|
			found_new = false
			raw     = scanner.http_get( base_url + page.to_s)
			File.open( '/Users/peter/temp/metacritic.html', 'w') {|io| io.print raw}
			#raw = IO.read( '/Users/peter/temp/rock_paper_shotgun.html')

			Nodes.parse( raw).css( 'a') do |anchor|
				if %r{^/game/} =~ anchor['href']
					[anchor['href']]
				end
			end.css('div.c-finderProductCard_title') do |element, href|
				unless found['https://www.metacritic.com' + href]
					found['https://www.metacritic.com' + href] = element['data-title']
					found_new = true
				end
			end

			break unless found_new
		end

		File.open( path,    'w') {|io| io.print JSON.generate( found)}
		0
	end

	def name
		'Metacritic'
  end

	def notify_bind( pagoda, link, page, game_id)
		Nodes.parse( page).css( 'li.full_review a') do |anchor|
			[anchor['href']]
		end.parent(5).css( 'div.source a') do |anchor, href|
			href = href.strip
			review = pagoda.link( href)
			unless review
				pagoda.add_link( anchor.text, 'Review', link.orig_title, href, 'Y')
				review = pagoda.link( href)
			end
			unless review.bound?
				review.bind( game_id)
			end
		end
	end
end
