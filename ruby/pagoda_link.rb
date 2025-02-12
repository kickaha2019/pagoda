# frozen_string_literal: true

class PagodaLink < PagodaRecord
  def initialize(owner, rec)
    super
    @bound      = false
    @bound_game = nil
  end

  def bad_tags
    digest = get_digest
    if digest['tags']
      digest['tags'].each do |tag|
        next if ['accept','reject'].include?(tag)
        found = false

        @owner.get('tag_aspects',:tag,tag).each do |rec|
          found = true
          next if ['accept','reject'].include?(rec[:aspect])
          unless rec[:aspect].nil?
            yield tag unless @owner.aspect?(rec[:aspect])
          end
        end

        unless found
          yield tag
        end
      end
    end
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
    @record[:comment] = msg
    @owner.update( 'link', :url, @record[:url], {comment:msg})
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

  def get_digest
    @owner.get_digest(@record)
  end

  def id
    timestamp
  end

  def label
    title
  end

  def link_aspects
    digest = get_digest
    aspects = []

    @owner.digest_aspects(self,digest) do |aspect|
      next if ['accept','reject'].include?(aspect)
      aspects << aspect
    end

    aspects.join(' ')
  end

  def link_date
    get_digest['link_year']
  end

  def name
    title
  end

  def orig_title
    (@record[:orig_title] && (@record[:orig_title].strip != '')) ? @record[:orig_title] : '???'
  end

  def set_checked
    @owner.start_transaction
    @owner.update( 'link', :url, @record[:url], @record)
    @owner.end_transaction
    @owner.refresh_link(@record[:url])
  end

  def static?
    #return false unless @record[:static]
    @record[:static]
  end

  def status
    if ! valid?
      if bound? && collation.nil?
        rejected? ? 'Rejected' : 'Ignored'
      else
        'Invalid'
      end
    elsif bound?
      collation ? 'Bound' : (rejected? ? 'Rejected' : 'Ignored')
    else
      rejected? ? 'Rejected' : 'Free'
    end
  end

  def suggest
    sh = @owner.get_site_handler( site)
    @owner.suggest( sh.reduce_title( sh.link_title( title, orig_title))) {|game, freq| yield game, freq}
  end

  # def suggest_analysis
  #   sh = @owner.get_site_handler( site)
  #   @owner.suggest_analysis( sh.link_title( title, orig_title)) {|combo, hits| yield combo, hits}
  # end

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

  def rejected?
    @record[:reject]
  end

  def valid?
    @record[:valid]
  end

  def verified( rec)
    @record[:title]      = rec[:title]
    ot = @record[:orig_title]
    ot = rec[:title] if ot.nil? || (ot.strip == '')
    @record[:orig_title] = rec[:orig_title] ? rec[:orig_title] : ot
    @record[:timestamp]  = rec[:timestamp]
    @record[:valid]      = rec[:valid]
    @record[:comment]    = rec[:comment]
    @record[:year]       = rec[:year] ? rec[:year] : nil
    @record[:reject]     = rec[:reject]

    if rec[:url] && (rec[:url] != @record[:url])
      raise "*** verified changed URL"
      #@owner.delete_link(@record[:url])
      #@record[:url] = rec[:url]
      #@owner.insert_link(@record)
    else
      @owner.start_transaction
      @owner.update( 'link', :url, @record[:url], @record)
      @owner.end_transaction
    end
  end
end
