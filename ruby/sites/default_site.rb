require_relative '../common'

class DefaultSite
  include Common

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

  def elide_nav_blocks(page)
    page.gsub( /<nav.*?<\/nav>/mi, '')
  end

  def elide_script_blocks(page)
    page.gsub( /<script.*?<\/script>/mi, '')
  end

  def link_title( * titles)
    titles[0]
  end

  def name
    'Website'
  end

  def post_load(pagoda, url, page)
    if m = /<title[^>]*>([^<]*)<\/title>/im.match( page)
      title = m[1].gsub( /\s/, ' ')
      title.strip.gsub( '  ', ' ')
      (title == '') ? {} : { 'title' => reduce_title( title ) }
    else
      { }
    end
  end

  def reduce_title( title)
    title
  end

  def validate_page(url,page)
    nil
  end

  def year_tolerance
    0
  end

  def digest_link(pagoda, url)
    status, response = http_get_threaded(url)

    unless status
      return status, false, response
    end

    if response.is_a? Net::HTTPRedirection
      return false, delete_redirects, "Redirected to #{redirected_url(url,response['location'])}"
    end

    unless response.is_a? Net::HTTPSuccess
      return false, false, response.message
    end

    return true, false, post_load(pagoda, url, response.body)
  end

  def delete_redirects
    false
  end
end
