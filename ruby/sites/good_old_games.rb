require_relative 'default_site'

class GoodOldGames < DefaultSite
  def initialize
    @info         = nil
  end

	def extract_card_product( html)
		html.split("\n").each do |line|
			if m = /^\s*cardProduct: ({.*)\s*,\s*$/.match( line)
				return JSON.parse( m[1])
			end
		end
		false
	end

	def find( scanner)
		path  = scanner.cache + "/gog.json"
		added = 0

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 6 * 24 * 60 * 60))
			page, seen, old_seen = 0, {}, -1

			while (seen.size > old_seen) && (page < 1000)
				old_seen = seen.size
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page+1}&order=asc:releaseDate"
				#File.open( '/Users/peter/temp/gog.html', 'w') {|io| io.print raw}
				#raw = IO.read( '/Users/peter/temp/gog.html')

				added += find_on_page( scanner, raw, seen)
				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( seen)}
		end

		scanner.purge_lost_urls
		added
	end

	def find_on_page( scanner, raw, seen)
		url, added = nil, 0

		raw.split( '<').each do |line|
			if m = /href="(https:\/\/www\.gog\.com\/en\/game\/[^"]*)"/.match( line)
				url = m[1].gsub( '/en/', '/')
			end
			if m = /title="([^"]*)"/.match( line)
				if url
					text = m[1]
					text.force_encoding( 'UTF-8')
					text.encode!( 'US-ASCII',
												:invalid => :replace, :undef => :replace, :universal_newline => true)
					added += scanner.add_link( text, url)
					seen[url] = text
					url = nil
				end
			end
		end

		added
	end

	def get_tags( page)
		found = ''

		if m = /"tags":\[([^\]]*)\]/mi.match( page)
			found += m[1]
		end

		if m = /"gameTags":\[([^\]]*)\]/mi.match( page)
			found += m[1]
		end

		return [] if found == ''
		tags = []
		found.scan( /"name":"([^"]*)"/) do |tag|
			tags << tag[0]
		end

		tags
	end

	def incremental( scanner)
    raw   = scanner.browser_get "https://www.gog.com/games?order=desc:releaseDate"
		# File.open( '/tmp/gog.html', 'w') {|io| io.print raw}
    seen  = {}
		added = find_on_page( scanner, raw, seen)
		scanner.error( 'Unable to find recent GOG game') unless seen.size > 0
    added
	end

	def name
		'GOG'
  end

	def year_tolerance
		1
	end

	def post_load(pagoda, url, page)
		{}.tap do |digest|
			if info = extract_card_product( page)
				digest['title']       = info['title']
				digest['description'] = info['description']

				digest['publishers']  = [info['publisher']] if info['publisher']
				if info['developers']
					digest['developers']  = info['developers'].collect {|developer| developer['name']}
				end

				if m = /^(\d+)-(\d+)-(\d+)T/.match( info['globalReleaseDate'])
					t = Time.new( m[1].to_i, m[2].to_i, m[3].to_i)
					digest['year'] = t.year if t <= Time.now
				end

				digest['platforms'] = ['GOG']
				info['supportedOperatingSystems'].each do |opsys|
					name = opsys['operatingSystem']['name']
					digest['platforms'] << 'Windows' if name == 'windows'
					digest['platforms'] << 'Mac'     if name == 'osx'
				end
			end

			tags = []
			tags << 'reject' unless digest['year']

			if /To play this game you also need/ =~ page
				tags << 'reject'
			end

			get_tags(page).each do |tag|
				tags << tag
			end
			digest['tags'] = tags.uniq
		end
	end

	def validate_page(url,page)
		page['title'] ? nil : 'Link deleted'
	end

	def digest_link(pagoda, url)
		super(pagoda, url.sub('/www.gog.com/game/','/www.gog.com/en/game/'))
	end

	def delete_redirects
		true
	end
end
