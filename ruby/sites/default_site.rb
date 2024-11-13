class DefaultSite
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

  def get_aspects(pagoda, url, page)
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

  def get_title(url, page, defval)
    if m = /<title[^>]*>([^<]*)<\/title>/im.match( page)
      title = m[1].gsub( /\s/, ' ')
      title.strip.gsub( '  ', ' ')
      (title == '') ? defval : title
    else
      defval
    end
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

  def override_verify_url( url)
    return false, false, '', ''
  end

  def post_load(pagoda, url, page)
    page
  end

  def reduce_title( title)
    title
  end

  def static?
    false
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
