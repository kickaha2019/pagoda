# frozen_string_literal: true
class PagodaGame < PagodaRecord
  include Common

  def aliases
    @owner.get( 'alias', :id, id).collect {|rec| PagodaAlias.new( @owner, rec)}
  end

  def aspects
    map = {}
    @owner.get( 'game_aspect', :id, id).each do |rec|
      map[rec[:aspect]] = rec[:flag]
    end
    map
  end

  def console
    'N'
  end

  def delete
    binds = @owner.get('bind',:id,id)

    @owner.start_transaction
    @owner.delete( 'game',           :id,   id)
    @owner.delete( 'alias',          :id,   id)
    @owner.delete( 'bind',           :id,   id)
    @owner.delete( 'game_aspect',    :id,   id)
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
    @record[:is_group]
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

  # def suggest_analysis
  #   @owner.suggest_analysis( name) {|combo, hits| yield combo, hits}
  #   aliases.each do |a|
  #     @owner.suggest_analysis( a.name) {|combo, hits| yield combo, hits}
  #   end
  # end

  def tablet
    'N'
  end

  def update( params)
    @owner.start_transaction
    @owner.delete( 'game',        :id, id)
    @owner.delete( 'alias',       :id, id)
    @owner.delete( 'game_aspect', :id, id)

    rec = {}
    [:id, :year, :name, :is_group, :developer, :publisher].each do |field|
      rec[field] = coerce( type_for_name(field), params[field]) if params[field]
    end
    rec[:reduced_name] = Names.reduce(rec[:name])

    if params[:group_name]
      group_recs = @owner.get( 'game', :name, params[:group_name].strip)
      rec[:group_id] = group_recs[0][:id] if group_recs && group_recs[0]
    end

    @record = @owner.insert( 'game', rec)
    names_seen = {rec[:name].downcase => true}

    (0..20).each do |index|
      name = params["alias#{index}".to_sym]
      next if name.nil? || (name.strip == '')
      next if names_seen[name.downcase]
      rec = {id:id,
             name:name,
             reduced_name:Names.reduce(name),
             hide:(params["hide#{index}".to_sym] == 'Y')}
      @owner.insert( 'alias', rec)
      names_seen[name.downcase] = true
    end

    @owner.aspect_name_and_types do |aspect, _|
      f = params["a_#{aspect}".to_sym]
      if ['Y','N'].include?( f)
        $pagoda.insert( 'game_aspect', {:id => id, :aspect => aspect, :flag => f})
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
      rec[field] = params[field] if params[field] #? params[field].to_s.strip : rec[field]
    end
    @record = @owner.insert( 'game', rec)
    @owner.end_transaction
    self
  end

  def update_from_link(link)
    details = {}
    digest  = link.get_digest

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
        @owner.insert( 'game_aspect', {:id => id, :aspect => aspect, :flag => true})
        @owner.end_transaction
      end
    end
  end

  # def web
  #   'N'
  # end
end


