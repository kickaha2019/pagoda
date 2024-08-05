require_relative 'default_site'

class GoodOldGames < DefaultSite
  def initialize
    @info         = nil
    @info_changed = 0
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
		path = scanner.cache + "/gog.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 6 * 24 * 60 * 60))
			page, seen, old_seen = 0, {}, -1

			while (seen.size > old_seen) && (page < 1000)
				old_seen = seen.size
				raw = scanner.browser_get "https://www.gog.com/games?page=#{page+1}&order=asc:releaseDate"
				#File.open( '/Users/peter/temp/gog.html', 'w') {|io| io.print raw}
				#raw = IO.read( '/Users/peter/temp/gog.html')

				find_on_page( scanner, raw, seen)
				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( seen)}
			stats = scanner.get_scan_stats( name, 'Store')
			stats['count'] = seen.size
			scanner.put_scan_stats( name, 'Store', stats)
		end
	end

	def find_on_page( scanner, raw, seen)
		url = nil
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
					scanner.add_link( text, url)
					seen[url] = text
					url = nil
				end
			end
		end
	end

	def filter( pagoda, link, page, rec)
		if m = /^(.*) on GOG\.com$/.match( rec[:title].strip)
			rec[:title] = m[1]
			if m1 = /^\-\d+% (.*)$/.match( rec[:title])
				rec[:title] = m1[1]
			end
		else
			rec[:valid]   = false
			rec[:comment] = 'Unexpected title'
			return false
		end

		@info = pagoda.get_yaml( 'gog.yaml') if @info.nil?
		tags  = @info['tags']
		found = get_tags( page)

		if found.empty?
			rec[:valid]   = false
			rec[:comment] = 'No tags'
			return false
		end

		rec[:ignore] = true
		found.each do |tag|
			action = tags[tag]
			action = action[0] if action.is_a?( Array)

			if action == 'accept'
				rec[:ignore] = false
      elsif action.nil?
        tags[tag] = 'ignore'
        @info_changed += 1
			end
		end

		found.each do |tag|
			if tags[tag] == 'reject'
				rec[:ignore] = true
			end
		end

		rec[:ignore] = true unless rec[:year]
		true
	end

	def get_derived_aspects( page)
		yield 'GOG'
		if info = extract_card_product( page)
			info['supportedOperatingSystems'].each do |opsys|
				name = opsys['operatingSystem']['name']
				yield 'Windows' if name == 'windows'
				yield 'Mac'     if name == 'osx'
			end
		end
	end

	def get_game_description( page)
		if info = extract_card_product( page)
			info['description']
		else
			''
		end
	end

	def get_game_details( url, page, game)
		if info = extract_card_product( page)
			game[:name]      = info['title']
			game[:publisher] = info['publisher']
			game[:developer] = info['developers'].collect {|d| d['name']}.join(', ') if info['developers']
			if m = /^(\d+)-(\d+)-(\d+)T/.match( info['globalReleaseDate'])
				t = Time.new( m[1].to_i, m[2].to_i, m[3].to_i)
				game[:year] = t.year if t <= Time.now
			end
		end
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

	def tag_aspects( pagoda, page)
		@info = pagoda.get_yaml( 'gog.yaml') if @info.nil?
		tags  = @info['tags']

		get_tags( page).each do |tag|
			actions = tags[tag]
			actions = [actions] if actions.is_a?( String)
			actions.each do |aspect|
				yield aspect unless ['accept','ignore','reject'].include?( aspect)
			end
		end
	end

  def terminate( pagoda)
    if @info_changed > 0
      pagoda.put_yaml( @info, 'gog.yaml')
      puts "... #{@info_changed} tags added to gog.yaml"
    end
  end

	def year_tolerance
		1
	end
end
