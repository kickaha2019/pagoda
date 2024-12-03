# frozen_string_literal: true

class PagodaLink < PagodaRecord
  def initialize(owner, rec)
    super
    @bound      = false
    @bound_game = nil
  end

  def bind( id)
    _bind(id)
    @owner.start_transaction
    @owner.delete( 'bind', :url, @record[:url])
    @owner.insert( 'bind', {
      url:@record[:url],
      id:id
    })
    @owner.end_transaction
  end

  def _bind( id)
    @bound      = true
    @bound_game = (id >= 0) ? @owner.game(id) : nil
  end

  def bound?
    @bound
  end

  def collation
    return nil unless @record
    @bound_game
  end

  def complain(msg)
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @record[:comment]    = msg
    @owner.insert( 'link', @record)
    @owner.end_transaction
    @owner.refresh_link(@record[:url])
  end

  def delete
    @owner.delete_link(@record[:url])
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
    #    begin
      digest = @owner.cached_digest(timestamp)
      (digest['aspects'] || []).uniq.join(' ')
    #   sh = @owner.get_site_handler(site)
    #   found = []
    #   sh.get_aspects(@owner,url,@owner.cache_read( timestamp)) do |aspect|
    #     found << aspect
    #   end
    #   found.uniq.join(' ')
    # rescue StandardError => e
    #   puts e.to_s
    # end
  end

  def link_date
    @owner.cached_digest(timestamp)['link_year']
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
    @owner.refresh_link(@record[:url])
  end

  def set_checked
    @owner.start_transaction
    @owner.delete( 'link', :url, @record[:url])
    @owner.insert( 'link', @record)
    @owner.end_transaction
    @owner.refresh_link(@record[:url])
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
    elsif unreleased?
      'Unreleased'
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
    @bound = false
    @bound_game = nil
  end

  def unreleased?
    @record[:unreleased] == 'Y'
  end

  def valid?
    @record[:valid] == 'Y'
  end

  def verified( rec)
    @record[:title]      = rec[:title]
    ot = @record[:orig_title]
    ot = rec[:title] if ot.nil? || (ot.strip == '')
    @record[:orig_title] = rec[:orig_title] ? rec[:orig_title] : ot
    @record[:timestamp]  = rec[:timestamp]
    @record[:valid]      = rec[:valid] ? 'Y' : 'N'
    @record[:comment]    = rec[:comment]
    @record[:year]       = rec[:year] ? rec[:year] : nil
    @record[:unreleased] = rec[:unreleased] ? 'Y' : 'N'

    if rec[:url] && (rec[:url] != @record[:url])
      raise "*** verified changed URL"
      #@owner.delete_link(@record[:url])
      #@record[:url] = rec[:url]
      #@owner.insert_link(@record)
    else
      @owner.start_transaction
      @owner.delete( 'link', :url, @record[:url])
      @owner.insert( 'link', @record)
      @owner.end_transaction
    end
  end
end
