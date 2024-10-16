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

  def deleted_title( title)
    false
  end

  def elide_nav_blocks(page)
    page.gsub( /<nav.*?<\/nav>/mi, '')
  end

  def elide_script_blocks(page)
    page.gsub( /<script.*?<\/script>/mi, '')
  end

  def filter( pagoda, link, page, rec)
    true
  end

  def get_aspects(pagoda, page)
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

  def get_link_year( page)
    nil
  end

  def ignore_redirects?
    false
  end

  def link_title( * titles)
    titles[0]
  end

  def name
    'Website'
  end

  def notify_bind( pagoda, link, page, game_id)
  end

  def override_verify_url( url)
    return false, false, '', ''
  end

  def reduce_title( title)
    title
  end

  def terminate( pagoda)
  end

  def validate_page(url,page)
    nil
  end

  def year_tolerance
    0
  end
end
