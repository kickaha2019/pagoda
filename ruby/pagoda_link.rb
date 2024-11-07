# frozen_string_literal: true

class PagodaLink < PagodaRecord
  def bind( id)
    @owner.start_transaction
    @owner.delete( 'bind', :url, @record[:url])
    @owner.insert( 'bind', {
      url:@record[:url],
      id:id
    })
    @owner.end_transaction
  end

  def bound?
    @owner.has?( 'bind', :url, @record[:url])
  end

  def collation
    return nil unless @record
    binds = @owner.get( 'bind', :url, @record[:url])
    if binds.size > 0
      return nil if binds[0][:id] < 0
      @owner.game( binds[0][:id])
    else
      nil
    end
  end

  def complain(msg)
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @record[:comment]    = msg
    @owner.insert( 'link', @record)
    @owner.end_transaction
  end

  def delete
    @owner.start_transaction
    @owner.delete( 'bind', :url, @record[:url])
    @owner.delete( 'link', :url, @record[:url])
    @owner.end_transaction
  end

  def generate?
    return false if type == 'Database'
    valid? && collation && (! static?)
  end

  def id
    timestamp
  end

  def label
    orig_title
  end

  def link_aspects
    begin
      sh = @owner.get_site_handler(site)
      found = []
      sh.get_aspects(@owner,url,@owner.cache_read( timestamp)) do |aspect|
        found << aspect
      end
      found.uniq.join(' ')
    rescue StandardError => e
      puts e.to_s
    end
  end

  def link_date
    begin
      sh = @owner.get_site_handler(site)
      sh.get_link_year( @owner.cache_read( timestamp))
    rescue StandardError => e
      puts e.to_s
    end
  end

  def name
    title
  end

  def orig_title
    (@record[:orig_title] && (@record[:orig_title].strip != '')) ? @record[:orig_title] : '???'
  end

  def patch_orig_title( title)
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @record[:orig_title] = title
    @owner.insert( 'link', @record)
    @owner.end_transaction
  end

  def set_checked
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @record[:changed] = 'N'
    @owner.insert( 'link', @record)
    @owner.end_transaction
  end

  def static?
    @owner.get_site_handler( @record[:site]).static?
    # return false unless @record[:static]
    # @record[:static] == 'Y'
  end

  def status
    if ! valid?
      if bound? && collation.nil?
        'Ignored'
      else
        'Invalid'
      end
    elsif bound?
      collation ? 'Bound' : 'Ignored'
    else
      'Free'
    end
  end

  def suggest
    sh = @owner.get_site_handler( site)
    @owner.suggest( sh.reduce_title( sh.link_title( title, orig_title))) {|game, freq| yield game, freq}
  end

  def suggest_analysis
    sh = @owner.get_site_handler( site)
    @owner.suggest_analysis( sh.link_title( title, orig_title)) {|combo, hits| yield combo, hits}
  end

  def timestamp
    @record[:timestamp] ? @record[:timestamp].to_i : 0
  end

  def title
    (@record[:title] && (@record[:title].strip != '')) ? @record[:title] : '???'
  end

  def unbind
    @owner.start_transaction
    @owner.delete( 'bind', :url, @record[:url])
    @owner.end_transaction
  end

  def valid?
    @record[:valid] == 'Y'
  end

  def verified( rec)
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @record[:url] = rec[:url] if rec[:url]

    unless @owner.has?( 'link', :url, @record[:url])
      @record[:title]      = rec[:title]
      ot = @record[:orig_title]
      ot = rec[:title] if ot.nil? || (ot.strip == '')
      @record[:orig_title] = rec[:orig_title] ? rec[:orig_title] : ot
      @record[:timestamp]  = rec[:timestamp]
      @record[:valid]      = rec[:valid] ? 'Y' : 'N'
      @record[:comment]    = rec[:comment]
      @record[:changed]    = rec[:changed] ? 'Y' : @record[:changed]
      @record[:year]       = rec[:year] ? rec[:year] : nil
      @owner.insert( 'link', @record)
    end
    @owner.end_transaction
  end
end
