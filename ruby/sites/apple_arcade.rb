require 'json'

class AppleArcade
  def extract_ember_json( html)
    inside, text = false, []
    html.split("\n").each do |line|
      if m = /^\s*<script[^>]*>({.*)$/.match( line)
        return JSON.parse( m[1])
      end

      if /^\s*<script name="schema:software-application"/ =~ line
        inside = true
      elsif inside
        return JSON.parse( line)
      end
    end

    false
  end

	def find( scanner)
		scanner.twitter_feed_links( 'applearcade') do |text, link|
			m = /^https:\/\/apps\.apple\.com\/app\/[^\/]*\/([a-z0-9]*)\?/.match( link)
			if m
				scanner.add_link( '', "https://apps.apple.com/app/#{m[1]}")
			else
				0
			end
		end
	end

  def get_game_details( page, game)
    if json = extract_ember_json( page)
      if dp = json['datePublished']
        if m = /(\d\d\d\d)/.match( dp)
          game[:year] = m[1]
        end
      end
      if author = json['author']
        game[:developer] = game[:publisher] = author['name']
      end
    end
  end
end
