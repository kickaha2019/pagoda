class DefaultSite
  def check_child_link( url, text, anchor)
  end

  def correlate_url( url)
    return nil, nil, nil
  end

  def filter( pagoda, link, page, rec)
    true
  end

  def get_game_description( page)
    ''
  end

  def get_game_details( url, page, game)
  end

  def name
    'Website'
  end

  def terminate( pagoda)
  end
end
