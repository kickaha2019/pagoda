require_relative 'default_site'

class DigestSite < DefaultSite
  def filter( pagoda, link, page, rec)
    page['aspects'].each do |tag|
      if tag == 'reject'
        rec[:ignore] = true
        return
      end
    end

    page['aspects'].each do |tag|
      if tag == 'accept'
        rec[:ignore] = false
        return
      end
    end

    rec[:ignore] = true
  end

  def get_aspects(pagoda, url, page)
    page['aspects'].each do |aspect|
      yield aspect unless ['accept','reject','ignore'].include?( aspect)
    end
  end

  def get_derived_aspects( page)
    if page['platforms']
      page['platforms'].each {|platform| yield platform}
    end
  end

  def get_game_description( page)
    null_if_blank(page['description'])
  end

  def get_game_details( url, page, game)
    game[:year]      = page['year']
    game[:name]      = null_if_blank(page['title'])
    game[:publisher] = page['publishers'] ? null_if_blank(page['publishers'].join(', ')) : nil
    game[:developer] = page['developers'] ? null_if_blank(page['developers'].join(', ')) : nil
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
