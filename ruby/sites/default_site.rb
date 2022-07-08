class DefaultSite
  def check_child_link( url, text, anchor)
  end

  def coerce_url( url)
    url
  end

  def correlate_url( url)
    return nil, nil, nil
  end

  def decode_month( name)
    if i = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"].index( name[0..2].downcase[0..2])
       i+1
    else
      0
    end
  end

  def filter( pagoda, link, page, rec)
    true
  end

  def get_derived_aspects( page)
  end

  def get_game_description( page)
    ''
  end

  def get_game_details( url, page, game)
  end

  def get_game_year( pagoda, link, page, rec)
    game = {}
    get_game_details( link.url, page, game)
    if game[:year]
      rec[:year] = game[:year]
    end
  end

  def name
    'Website'
  end

  def tag_aspects( pagoda, page)
  end

  def terminate( pagoda)
  end
end
