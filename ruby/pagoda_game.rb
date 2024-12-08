# frozen_string_literal: true
class PagodaGame < PagodaRecord
  def initialize( owner, rec)
    super

    owner.add_name( name, id)

    aliases.each do |arec|
      owner.add_name( arec.name, id)
    end
  end

  def aliases
    @owner.get( 'alias', :id, id).collect {|rec| PagodaAlias.new( @owner, rec)}
  end

  def aspects
    map = {}
    @owner.get( 'aspect', :id, id).each do |rec|
      f, a = rec[:flag], rec[:aspect]
      if f == 'Y'
        map[a] = true
      elsif f == 'N'
        map[a] = false
      end
    end
    map
  end

  def console
    'N'
  end

  def delete
    @owner.delete_name( name, id)
    aliases.each do |a|
      @owner.delete_name( a.name, id)
    end
    links do |l|
      @owner.delete_name( l.title, id)
    end
    binds = @owner.get('bind',:id,id)

    @owner.start_transaction
    @owner.delete( 'game',           :id,   id)
    @owner.delete( 'alias',          :id,   id)
    @owner.delete( 'bind',           :id,   id)
    @owner.delete( 'aspect',         :id,   id)
    @owner.delete( 'aspect_suggest', :game, id)
    @owner.end_transaction

    binds.each do |bind|
      @owner.refresh_link(bind[:url])
    end
  end

  def game_type
    flagged = aspects
    known = []
    @owner.aspect_name_and_types {|name, _| known << name}
    return '?' unless flagged['Adventure']
    ['HOG','Physics','RPG','Stealth','Visual novel','VR'].each do |unwanted|
      raise "Unknown aspect #{unwanted}" unless known.include?( unwanted)
      return '?' if flagged[unwanted]
    end
    'A'
  end

  def group?
    @record[:is_group] == 'Y'
  end

  def group_name
    if @record[:group_id]
      if group = @owner.get( 'game', :id, @record[:group_id])[0]
        group[:name]
      else
        nil
      end
    else
      nil
    end
  end

  def links
    @owner.get( 'bind', :id, id).each do |rec|
      if link = @owner.link( rec[:url])
        yield link
      end
    end
  end

  def mac
    'N'
  end

  def pc
    'N'
  end

  def official_site
    links do |link|
      if link.site == 'Website' && link.type == 'Official'
        return link.url
      end
    end
    ''
  end

  def phone
    'N'
  end

  def sort_name
    @owner.sort_name( name)
  end

  def suggest_analysis
    @owner.suggest_analysis( name) {|combo, hits| yield combo, hits}
    aliases.each do |a|
      @owner.suggest_analysis( a.name) {|combo, hits| yield combo, hits}
    end
  end

  def tablet
    'N'
  end

  def update( params)
    @owner.delete_name( name, id)
    aliases.each do |a|
      @owner.delete_name( a.name, id)
    end

    @owner.start_transaction
    @owner.delete( 'game',    :id, id)
    @owner.delete( 'alias',   :id, id)
    @owner.delete( 'aspect',  :id, id)

    rec = {}
    [:id, :name, :year, :is_group, :developer, :publisher].each do |field|
      rec[field] = params[field] ? params[field].to_s.strip : nil
    end

    if params[:group_name]
      group_recs = @owner.get( 'game', :name, params[:group_name].strip)
      rec[:group_id] = group_recs[0][:id] if group_recs && group_recs[0]
    end

    @record = @owner.insert( 'game', rec)
    @owner.add_name( rec[:name], id)
    names_seen = {rec[:name].downcase => true}

    (0..20).each do |index|
      name = params["alias#{index}".to_sym]
      next if name.nil? || (name.strip == '')
      next if names_seen[name.downcase]
      rec = {id:id, name:name, hide:params["hide#{index}".to_sym]}
      @owner.insert( 'alias', rec)
      @owner.add_name( rec[:name], id)
      names_seen[name.downcase] = true
    end

    @owner.aspect_name_and_types do |aspect, _|
      f = params["a_#{aspect}".to_sym]
      if ['Y','N'].include?( f)
        $pagoda.insert( 'aspect', {:id => id, :aspect => aspect, :flag => f})
      end
    end

    os = official_site
    if params[:website] && (os != params[:website])
      @owner.delete( 'bind', :url, os)
      @owner.delete( 'link', :url, os)
      @owner.refresh_link(os)
      if params[:website] != ''
        rec = {:url => params[:website], :site => 'Website', :type => 'Official', :title => name}
        @owner.insert( 'link', rec)
        @owner.insert( 'bind', {:url => params[:website], :id => id})
        @owner.refresh_link rec[:url]
      end
    end

    @owner.end_transaction
    self
  end

  def update_details( params)
    @owner.start_transaction
    @owner.delete( 'game',    :id, id)
    rec = {}
    @record.each_pair {|k,v| rec[k] = v}
    [:year, :developer, :publisher].each do |field|
      rec[field] = params[field] ? params[field].to_s.strip : rec[field]
    end
    @record = @owner.insert( 'game', rec)
    @owner.end_transaction
    self
  end

  def update_from_link(link)
    details = {}
    digest  = @owner.cached_digest(link.timestamp)

    if year.nil? && digest['year']
      details[:year] = digest['year']
    end

    if developer.nil? && digest['developers']
      details[:developer] = digest['developers'].join(', ')
    end

    if publisher.nil? && digest['publishers']
      details[:publisher] = digest['publishers'].join(', ')
    end

    unless details.empty?
      update_details( details)
    end

    cache_aspects = aspects

    @owner.digest_aspects(link,digest) do |aspect|
      next if ['accept','reject'].include?(aspect)
      unless cache_aspects.has_key?(aspect)
        @owner.start_transaction
        @owner.insert( 'aspect', {:id => id, :aspect => aspect, :flag => 'Y'})
        @owner.end_transaction
      end
    end
  end

  # def web
  #   'N'
  # end
end


