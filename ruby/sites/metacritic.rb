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
			return if raw.nil?
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

	def post_load(pagoda, url, page)
		{}.tap do |digest|
			nodes = Nodes.parse(page)

			nodes.css('div.c-productHero_title h1') do |title|
				digest['title'] = title.text
			end

			nodes.css('span.c-productionDetailsGame_description') do |desc|
				digest['description'] = desc.text
			end

			get_info(nodes,'Initial Release Date:') do |date|
				if m = /(\d\d\d\d)$/.match( date )
					digest['year'] = m[1].to_i
				end
			end

			digest['developers']  = get_companies(nodes,'Developer:')
			digest['publishers']  = get_companies(nodes,'Publisher:')
		end
	end

	def get_companies(nodes, type)
		[].tap do |companies|
			get_info(nodes, type) do |name|
				companies << name
			end
		end
	end

	def get_info(nodes, type)
		nodes.css( 'span.u-block') do |span|
			if span.text == type
				[]
			else
				nil
			end
		end.parent( 1).css( '.g-color-gray70') do |span1|
			yield span1.text.strip
		end
	end
end
