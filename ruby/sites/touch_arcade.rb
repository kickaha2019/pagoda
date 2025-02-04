require_relative 'default_site'

class TouchArcade < DefaultSite
	def find( scanner)
		path = scanner.cache + "/touch_arcade.json"

		unless File.exist?( path) && (File.mtime( path) > (Time.now - 2 * 24 * 60 * 60))
			urls, page, old_count = {}, 0, -1

			while old_count < urls.size
				old_count = urls.size
				begin
					raw = scanner.http_get "https://toucharcade.com/category/reviews/page/#{page+1}"
					return if raw.nil?
				rescue Exception => bang
					break
				end

				raw.split( "\n").each do |line|
					if m = /<a href=\"([^"]*)\" rel=\"bookmark\">([^<]*)<\/a>/.match( line)
						text = m[2]
						text.force_encoding( 'UTF-8')
						text.encode!( 'US-ASCII',
													:invalid => :replace, :undef => :replace, :universal_newline => true)
						urls[m[1]] = text
					end
				end

				page += 1
			end

			File.open( path, 'w') {|io| io.print JSON.generate( urls)}
		end

		JSON.parse( IO.read( path)).each_pair do |url, name|
			scanner.add_link( name, url)
		end
	end

	def incremental( scanner)
		scanner.html_anchors( 'https://toucharcade.com/category/reviews/') do |link, label|
			if /^https:\/\/toucharcade\.com\/.*-review(-|\/)/ =~ link
				link = link.split('?')[0]
				scanner.add_link( label, link)
			else
				0
			end
		end
	end

  def name
    'TouchArcade'
  end
end
