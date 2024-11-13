require_relative 'default_site'

class DigestSite < DefaultSite
  def get_aspects(pagoda, url, page)
    page['aspects'].each do |aspect|
      yield aspect
    end
  end

  def get_game_description( page)
    null_if_blank(page['description'])
  end

  def get_game_details( url, page, game)
    game[:year]      = page['year']
    game[:name]      = null_if_blank(page['title'])
    game[:publisher] = null_if_blank(page['publishers'].join(', '))
    game[:developer] = null_if_blank(page['developers'].join(', '))
  end

  def get_title(url, page, defval)
    null_if_blank(page['title'])
  end

  def name
    'Digest'
  end

  def null_if_blank(text)
    text.nil? ? nil : (text.strip.empty? ? nil : text.strip)
  end

  def year_tolerance
    0
  end
end
