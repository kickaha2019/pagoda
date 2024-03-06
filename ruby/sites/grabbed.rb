require_relative 'default_site'

class Grabbed < DefaultSite
	def incremental( scanner)
		path  = scanner.cache + "/grabbed.txt"
		added = 0

		left = IO.readlines( path).select do |line|
			url = line.strip

			title = 'Unknown'
			begin
				raw   = scanner.http_get url
				if m = /<title>([^<]*)<\/title>/mi.match( raw)
					title = m[1].strip
				end
			rescue
			end
			
			site, type, link = * scanner.correlate_site( url)
			if site
				added += scanner.add_link( title, link, site, type)
				false
			else
				added += scanner.add_link( title, url)
				true
			end
		end

		File.open( path, 'w') do |io|
			io.print left.join( '')
		end

		added
	end

	def name
		'Grabbed'
	end
end
