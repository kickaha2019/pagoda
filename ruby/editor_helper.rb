require 'sinatra/base'
require_relative 'pagoda'
require_relative 'common'
require_relative 'contexts/default_context'
require_relative 'contexts/aspect_context'
require_relative 'contexts/no_aspect_type_context'
require_relative 'contexts/year_context'
require_relative 'contexts/company_context'

module Sinatra
  module EditorHelper
    include Common

    @@selected_game = -1
    @@timestamps    = {}
    @@contexts      = {0 => DefaultContext.new}

    def add_game_from_link( link_url)
      link_rec = $pagoda.link( link_url)
      if collated = link_rec.collation
        return "/game/#{collated.id}/"
      end

      if link_rec.timestamp <= 1000
        return ''
      end

      #p ['add_game_from_link', link_url]
      sh = $pagoda.get_site_handler( link_rec.site)
      g = {:name => sh.reduce_title( link_rec.title),
           :id => $pagoda.next_value( 'game', :id)}

      begin
        game = $pagoda.create_game( g)
        link_rec.bind( g[:id])
        game.update_from_link(link_rec)
        "/game/#{g[:id]}/"
      rescue Exception => bang
        puts( bang.message + "\n" + bang.backtrace.join( "\n"))
        ''
      end
    end

    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 60, alias_rec ? alias_rec.name : '') +
      '</td><td>' +
      checkbox_element( "hide#{index}", alias_rec ? alias_rec.hide : true)
    end

    def aliases_records( context, search)
      games_records( context, search).select {|g| g.aliases.size > 0}
    end

    def aspect_element( name, value, show)
      colour, setting = 'white', '?'
      if value == false
        colour, setting = 'red', 'N'
      end
      if value == true
        colour, setting = 'lime', 'Y'
      end

      if show
      html = <<"ASPECT_ELEMENT"
<div id="d_#{name}" style="background: #{colour}" onclick="change_aspect( event, '#{name}')">  
<span>#{name}</span>     
<input id="i_#{name}" type="hidden" name="a_#{name}" value="#{setting}">
</div>
ASPECT_ELEMENT
      else
        html = <<"HIDDEN_ASPECT_ELEMENT"
<input id="i_#{name}" type="hidden" name="a_#{name}" value="#{setting}">
HIDDEN_ASPECT_ELEMENT
      end

      html.gsub( />\s+</m, '><')
    end

    def aspect_action( aspect, action)
      "<button onclick=\"aspect_action( '#{e(aspect)}', '#{action}');\">#{action.capitalize}</button>"
    end

    def aspect_delete( aspect)
      $pagoda.start_transaction
      $pagoda.delete( 'game_aspect', :aspect, aspect)
      $pagoda.end_transaction
    end

    def aspect_type_records
      types = []
      $pagoda.select('aspect') do |info|
        types << info[:type]
      end

      types.select {|type| type}.uniq.sort.collect do |type|
        [type, games_records(new_no_aspect_type_context(type,'name'), '').size]
      end
    end

    def bind_id( link_rec)
      return nil if ! link_rec.bound?
      game_rec = link_rec.collation
      return -1 if game_rec.nil?
      game_rec.id
    end

    def bind_link( link_url, game_id=nil)
      link_rec = $pagoda.link( link_url)
      return '' if link_rec.nil?

      if ! game_id.nil?
        bind_game = game_id
      else
        bind_game = @@selected_game
      end

      return '' if bind_game < 0
      return '' if bind_id( link_rec) == bind_game
      link_rec.bind( bind_game)

      game_rec = $pagoda.game( bind_game)
      game_rec.update_from_link(link_rec)
      'Bound'
    end

    def check_name( name, id)
      $pagoda.check_unique_name( name, id) ? 'Y' : 'N'
    end

    def checkbox_element( name, checked, extras='')
      "<input type=\"checkbox\" name=\"#{name}\" value=\"Y\" #{checked ? 'checked' : ''} #{extras}>"
    end

    def collation( link_url)
      link = $pagoda.link( link_url)
      return {'link':'','year':''} unless link
      collation = link.collation
      return {'link':'','year':''} if collation.nil?
      link_html = "<a title=\"#{t(collation.name)}\" href=\"/game/#{collation.id}\">#{h(collation.name,40)}</a>"
      {'game':collation.id, 'link':link_html,'year':"#{collation.year}"}
    end

    def collation_year( link_url)
      collation = $pagoda.link( link_url).collation
      collation.nil? ? '' : collation.year
    end

    def combo_box( combo_name, values, current_value, base_url, html)
      defn = ["#{combo_name.capitalize}:&nbsp;"]
      defn << "<select id=\"#{combo_name}\" onchange=\"change_combo('#{combo_name}', '#{base_url}')\">"
      values.each do |value|
        selected = (current_value == value) ? 'selected' : ''
        defn << "<option value=\"#{e(value.gsub('?',''))}\"#{selected}>#{h(value)}</option>"
      end
      defn << '</select>'
      html << defn.join('')
    end

    def company_add(company)
      $pagoda.start_transaction
      $pagoda.insert('company',
                     {name:company, reduced_name:Names.reduce(company)})
      $pagoda.end_transaction
    end

    def company_add_alias(company,aka)
      return unless company_exists?(company)
      $pagoda.start_transaction
      old = $pagoda.get('company_alias',:name,aka)
      $pagoda.delete('company',:name,aka)
      $pagoda.delete('company_alias',:name,aka)
      $pagoda.delete('company_alias',:alias,aka)
      $pagoda.insert('company_alias',{:name => company, :alias => aka})
      old.each do |rec|
        $pagoda.insert('company_alias',{:name => company, :alias => rec[:alias]})
      end
      $pagoda.end_transaction
    end

    def company_delete(company)
      $pagoda.start_transaction
      $pagoda.delete('company',:name,company)
      $pagoda.delete('company_alias',:name,company)
      $pagoda.delete('company_alias',:alias,company)
      $pagoda.end_transaction
    end

    def company_add_action(company)
      "<button onclick=\"company_add_action( '#{e(e(company))}');\">Add</button>"
    end

    def company_alias?(company)
      $pagoda.has?('company_alias',:alias,company)
    end

    def company_alias_action(company,aka)
      "<button onclick=\"company_alias_action( '#{e(e(company))}', '#{e(e(aka))}');\">Alias</button>"
    end

    def company_aliases(company)
      $pagoda.get('company_alias',:name,company).collect do |rec|
        rec[:alias]
      end.sort
    end

    def company_delete_action(company)
      "<button onclick=\"company_delete_action( '#{e(e(company))}');\">Delete</button>"
    end

    def company_dereference(company)
      $pagoda.get('company_alias',:alias,company)[0][:name]
    end

    def company_exists?(company)
      $pagoda.has?('company',:name,company) ||
      $pagoda.has?('company_alias',:alias,company)
    end

    def company_suggestions(name)
      $company_names.suggest(name,50) do |name, _|
        yield name
      end
    end

    def companies_records(known,search)
      if known == 'Y'
        $pagoda.select('company') do |company|
          search.strip.empty? ? true : company[:name].downcase.include?(search.strip)
        end.collect {|rec| rec[:name]}
      else
        IO.readlines(ARGV[1]+'/unknown_companies.txt').collect {|name| name.strip}
      end
    end

    def contains_string( text, search)
      text   = text.to_s
      search = search.downcase
      return true if text.downcase.index( search)
      Names.reduce( text).index( search)
    end

    def d( text)
      CGI.unescape( text)
    end

    def delete_game( id)
      game_rec = $pagoda.game( id)
      game_rec.delete if game_rec != nil
    end

    def delete_link( link_url)
      link_rec = $pagoda.link( link_url)
      link_rec.delete if link_rec
      'Deleted'
    end

    def duplicate_game( id)
      new_id = $pagoda.next_value( 'game', :id)
      $pagoda.start_transaction
      game_rec = $pagoda.get( 'game', :id, id)[0].clone
      game_rec[:id] = new_id
      game_rec[:name] += " DUPLICATE #{new_id}"
      game_rec[:year] = nil
      game_rec[:developer] = nil
      game_rec[:publisher] = nil
      $pagoda.insert( 'game', game_rec)
      $pagoda.get( 'game_aspect', :id, id).each do |aspect|
        aspect_rec = aspect.dup
        aspect_rec[:id] = new_id
        $pagoda.insert( 'game_aspect', aspect_rec)
      end
      $pagoda.end_transaction
      new_id
    end

    def form_combo_box( combo_name, values, current_value)
      defn = ["<select name=\"#{combo_name}\">"]
      values.each do |value|
        selected = (current_value == value) ? 'selected' : ''
        defn << "<option value=\"#{value}\"#{selected}>#{h(value)}</option>"
      end
      defn << '</select>'
      defn.join('')
    end

    def game_group_action()
      "<button onclick=\"set_group(); return false;\">Set</button>"
    end

    def game_link( id)
      game_rec = $pagoda.game( id)
      return '' if game_rec.nil?
      "<a href=\"/game/#{id}/\">#{h(game_rec.name)}</a>"
    end

    def games_by_aspect_records(aspect_type)
      map = Hash.new {|h,k| h[k] = 0}

      $pagoda.games do |game|
        found = false
        game.aspects.each_pair do |a,f|
          found = true
          map[a] += 1 if f
        end
        unless found
          map['None'] += 1
        end
      end

      aspects = []
      $pagoda.select('aspect') do |record|
        if record[:type].nil? || (record[:type] == aspect_type)
          aspects << [record[:name], record[:index]]
        end
      end

      aspects.sort.collect do |aspect|
        [aspect[0], aspect[1], map[aspect[0]]]
      end + (aspect_type.empty? ? [['None', '', map['None']]] : [])
    end

    def games_records( context, search)
      $pagoda.games do |game|
        next unless get_context(context).select_game?($pagoda,game)

        selected = contains_string( game.name, search)
        game.aliases.each do |a|
          selected = true if contains_string( a.name, search)
        end

        selected
      end
    end

    def get_context(index)
      @@contexts[index]
    end

    def get_digest_as_yaml( url)
      if link = $pagoda.link( url )
        link.get_digest.to_yaml
      else
        ''
      end
    end

    def get_locals( params, defs)
      locals = {}
      defs.each_pair do |k,v|
        locals[k] = params[k] ? params[k] : v
        locals[k] = locals[k].to_i if v.is_a?( Integer)
        if [true, false].include?( v) && locals[k].is_a?( String)
          locals[k] = (locals[k] == 'Y')
        end
      end
      locals
    end

    def google_search( label, game_id, texts)
      text = texts.join( ' ').downcase.gsub( /[^0-9a-z]/, ' ').gsub( ' ', '+')
      <<SEARCH
<a target="_blank" 
onclick="write_id_to_grabbed(#{game_id})"
href="https://www.google.com/search?q=#{text}">#{label}</a>
SEARCH
    end

    def h(text, max_chars=1000)
      return '' if text.nil?
      text = text[0...max_chars] if text.size > max_chars
      Rack::Utils.escape_html(text)
    end

    def ignore_link( link_url)
      link_rec = $pagoda.link( link_url)
      return '' if link_rec.rejected?
      return '' if bind_id( link_rec) == -1
      link_rec.bind( -1)
      'Ignored'
    end

    def ignored_to_reprieve_records
      recs = []

      $pagoda.links do |link|
        next unless link.status == 'Ignored'
        next if link.static?
        next if $pagoda.has?( 'visited', :key, "ignore_reprieve:#{link.url}")
        suggested = []
        $pagoda.suggest( link.title) {|game, freq| suggested << [game.id, freq]}
        recs << [link, suggested] if suggested.size > 0
      end

      recs.sort_by {|rec| [rec[1].inject(0) {|r,e| r + e[1]}, rec[0].title]}
    end

    def input_element( name, len, value, extras='')
      "<input type=\"text\" name=\"#{name}\" maxlength=\"200\" size=\"#{len}\" value=\"#{h(value)}\" #{extras}>"
    end

    def link_action( rec, action, row=0)
      "<button onclick=\"link_action( '#{e(e(rec.url))}', '#{action}', #{row});\">#{action.capitalize}</button>"
    end

    def link_add_action( rec)
      "<button onclick=\"link_add_action( '#{e(e(rec.url))}');\">Add</button>"
    end

    def link_bind_action( rec, game_id)
      "<button onclick=\"link_bind_action( '#{e(e(rec.url))}', #{game_id});\">Bind</button>"
    end

    def link_flagged?( rec)
      rec.comment
    end

    def link_records( site, type, status, search)
     $pagoda.links do |rec|
        chosen = rec.name.to_s.downcase.index( search.downcase)
        unless chosen
          chosen = rec.url.downcase.index( search.downcase)
        end
        chosen = false unless ((rec.site == site) || (site == 'All'))
        chosen = false unless (rec.type == type) || (type == 'All')
        if status == 'Flagged'
          chosen = false unless link_flagged?(rec)
        else
          chosen = false unless (link_status(rec) == status) || (status == 'All')
        end
        chosen
      end
    end

    def link_site_combo( view, combo_name, current_site, current_type, current_status, html)
      values = $pagoda.links.collect {|s| s.site}.uniq.sort
      values << 'All'
      unless values.index( current_site)
        current_site = 'All'
      end
      base_url = "/#{view}?status=#{current_status}&type=#{current_type}&site="
      combo_box( combo_name, values, current_site, base_url, html)
      current_site
    end

    def link_status( rec)
      rec.status
    end

    def link_status_combo( view, combo_name, current_site, current_type, current_status, html)
      values = []
      $pagoda.links do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        next unless (current_type == 'All') || (current_type == rec.type)
        values << link_status( rec)
        values << 'Flagged' if link_flagged?( rec)
      end
      values = values.uniq.sort
      values << 'All'
      unless values.index( current_status)
        current_status = 'All'
      end
      base_url = "/#{view}?site=#{current_site}&type=#{current_type}&status="
      combo_box( combo_name, values, current_status, base_url, html)
      current_status
    end

    def link_type_combo( view, combo_name, current_site, current_type, current_status, html)
      types = []
      $pagoda.links do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        types << rec.type
      end
      types = types.uniq.sort
      types << 'All'
      unless types.index( current_type)
        current_type = 'All'
      end
      base_url = "/#{view}?site=#{current_site}&status=#{current_status}&type="
      combo_box( combo_name, types, current_type, base_url, html)
      current_type
    end

    def links_by_site_and_type
      cache = Hash.new {|h,k| h[k] = Hash.new {|h1,k1| h1[k1] = []}}
      $pagoda.links do |rec|
        cache[rec.site][rec.type] << rec
      end
      cache.keys.sort.each do |site|
        cache[site].keys.sort.each do |type|
          yield site, type, cache[site][type]
        end
      end
    end

    def multiple_genre_records
      unvisited = []

      genre_aspects = {}
      $pagoda.select('aspect') do |record|
        genre_aspects[record[:name]] = true if record[:type] == 'genre'
      end

      $pagoda.games do |game|
        visited = $pagoda.get( 'visited', :key, "multiple_genre:#{game.id}")
        if visited.empty?
          genres = 0
          game.aspects.each_pair do |aspect, flag|
            genres += 1 if flag && genre_aspects[aspect]
          end
          unvisited << game if genres > 1
        end
      end

      unvisited.sort_by {|rec| rec.id}
    end

    def new_aspect_context(aspect,sort_by)
      (@@contexts.size+1).tap do |context|
        @@contexts[context] = AspectContext.new(aspect,sort_by)
      end
    end

    def new_company_context(company,sort_by)
      (@@contexts.size+1).tap do |context|
        @@contexts[context] = CompanyContext.new(company,sort_by)
      end
    end

    def new_no_aspect_type_context(type, sort_by)
      (@@contexts.size+1).tap do |context|
        @@contexts[context] = NoAspectTypeContext.new(type,sort_by)
      end
    end

    def new_year_context(year,sort_by)
      (@@contexts.size+1).tap do |context|
        @@contexts[context] = YearContext.new(year,sort_by)
      end
    end

    def pardon_link( link_url)
      link_rec = $pagoda.link( link_url)
      if link_rec
        link_rec.verified(
            {:title     => link_rec.title,
                 :timestamp => link_rec.timestamp,
                 :valid     => true,
                 :year      => link_rec.year}
        )
        link_rec.status
      else
        ''
      end
    end

    def redirect_link( link_url)
      link_rec = $pagoda.link( link_url)
      if link_rec
        if m = /^Redirected to (.*)$/.match( link_rec.comment)
          new_url = m[1]
          title = (/Moved Permanently/ =~ link_rec.title) ? link_rec.orig_title : link_rec.title
          if $pagoda.add_link( link_rec.site, link_rec.type, title, new_url)
            new_link = $pagoda.link( new_url)
            binds = $pagoda.get( 'bind', :url, link_rec.url)
            if binds.size > 0
              new_link.bind( binds[0][:id])
            end

            link_rec.delete
            return 'Redirected'
          end
        end
      end
      ''
    end

    def refresh_metadata
    end

    def scan_records(field)
      $pagoda.settings['overnight'].each do |scan|
        records = []

        $pagoda.select('history') do |history|
          if (history[:site]   == scan['site']) &&
             (history[:type]   == scan['type']) &&
             (history[:method] == scan['method'])
            records << history
          end
        end
        next if records.empty?

        records.sort_by! do |record|
          record[:timestamp]
        end
        records.reverse!
        values = records.map {|rec| rec[field.to_sym] }
        yield scan['site'], scan['type'], scan['method'], records[0][:timestamp], values
      end
    end

    def selected_game
      games = $pagoda.get( 'game', :id, @@selected_game.to_i)
      games.empty? ? ' ' : games[0][:name]
    end

    def selected_game_id( new_id)
      @@selected_game if new_id == 0
      @@selected_game = new_id
    end

    def set_selected_game( id)
      @@selected_game = id
    end

    def set_aspect( game_id, aspect, flag)
      game            = $pagoda.game( game_id)
      aspects         = game.aspects
      aspects[aspect] = (flag != 'N')

      $pagoda.start_transaction
      $pagoda.delete( 'game_aspect', :id, game_id)
      aspects.each_pair do |a,f|
        $pagoda.insert( 'game_aspect', {:id => game_id, :aspect => a, :flag => (f ? 'Y' : 'N')})
      end
      $pagoda.end_transaction
    end

    def set_checked( game_id, flag)
      $pagoda.start_transaction
      $pagoda.insert( 'visited', {key: "#{flag}:#{game_id}",
                                  timestamp: Time.now.to_i})
      $pagoda.end_transaction
    end

    def set_official_checked( game_id)
      $pagoda.get( 'bind', :id, game_id).each do |bind_rec|
        link = $pagoda.link( bind_rec[:url])
        if link && (link.site == 'Website')
          link.set_checked
          break
        end
      end
    end

    def self.setup
      $pagoda = Pagoda.release( ARGV[0], true)

      $debug = false
      ARGV[2..-1].each do |arg|
        $debug = true if /^debug=true$/i =~ arg
      end

      $game_names = Names.new
      $game_names.listen( $pagoda, 'game', :reduced_name, :id)
      $game_names.listen( $pagoda, 'alias', :reduced_name, :id)
      $pagoda.log 'Populate game names repository'

      $company_names = Names.new
      $company_names.listen( $pagoda, 'company', :reduced_name, :name)
      $pagoda.log 'Populate company names repository'

      $suggestions = Names.new
      $suggestions.listen( $pagoda, 'suggest', :reduced_title, :url)
      $pagoda.log 'Populate suggestions names repository'
    end

    def sort_name( name)
      name = name.upcase
      if m = /^(A|AN|THE)\s+(.*)$/.match( name)
        m[2]
      else
        name
      end
    end

    def suggest_bind_action( rec, id, row=0)
      "<button onclick=\"suggest_bind_action( '#{e(e(rec[:url]))}', #{id}, #{row});\">Bind</button>"
    end

    def suggest_games(link_title)
      $game_names.suggest(link_title,100) do |name, key|
        yield name, $pagoda.game(key)
      end
    end

    def suggests_records( site, type, search)
      found = []
      $pagoda.get('suggest', :site, site) do |rec|
        if (rec[:type] == type) &&
           (rec[:title] || '???').downcase.include?( search.downcase.strip)
          found << rec
        end
      end
      found
    end

    def suggested_by_site_and_type
      map = Hash.new {|h,k| h[k] = Hash.new{|h1,k1| h1[k1] = 0}}
      $pagoda.select('suggest') do |rec|
        map[rec[:site]][rec[:type]] += 1
      end
      map
    end

    def suggested_links_records(id)
      [].tap do |suggests|
        $suggestions.suggest($pagoda.game(id).name,200) do |name, url|
          next if $pagoda.has?('link', :url, url)
          suggests << $pagoda.get('suggest', :url, url)[0]
          break if suggests.size >= 100
        end
      end
    end

    def summary_line( site, type, counts, totals, html)
      return if site == ''
      html << "<tr><td>#{h(site)}</td><td>#{type}</td>"

      ['Invalid', 'Free', 'Ignored', 'Bound', 'Flagged', 'Rejected', 'Suggested'].each do |status|
        c = counts[status]
        colour = (status == 'Free') ? 'lime' : 'white'
        colour = 'cyan' if c[2] > 0
        colour = 'red' if c[1] > 0

        if c[0] > 0
          if status == 'Suggested'
            url = "/suggests?site=#{e(site)}&type=#{type}&search=&page=1"
          else
            url = "/links?site=#{e(site)}&type=#{type}&status=#{status}&search=&page=1"
          end
          html << "<td style=\"background: #{colour}\"><a target=\"_blank\" href=\"#{url}\">#{c[0]}</a></td>"
          totals[status] = [0,0,0] if ! totals.has_key?( status)
          c.each_index {|i| totals[status][i] += c[i]}
        else
          html << "<td></td>"
        end
      end
      html << '</tr>'
    end

    def t(text)
      return '' if text.nil?
      text.gsub( /["'<>&]/, ' ')
    end

    def tag_aspect_element( index, aspect)
      values = ['','accept','reject','Unknown']
      $pagoda.select('aspect') do |rec|
        values << rec[:name]
      end
      defn = []
      defn << "<select name=\"aspect#{index}\">"
      values.each do |value|
        selected = (aspect == value) ? 'selected' : ''
        defn << "<option value=\"#{e(value.gsub('?',''))}\"#{selected}>#{h(value)}</option>"
      end
      defn << '</select>'
      defn.join('')
    end

    def tag_aspects(tag)
      [].tap do |aspects|
        $pagoda.get('tag_aspects',:tag, tag).each do |rec|
          aspects << rec[:aspect] unless rec[:aspect].nil?
        end
      end
    end

    def tags_aspect_combo( view, combo_name, current_aspect, html)
      values = ['All','None','Unknown']
      $pagoda.select('aspect') do |rec|
        values << rec[:name]
      end
      unless values.index( current_aspect)
        current_aspect = 'All'
      end
      base_url = "/#{view}?aspect="
      combo_box( combo_name, values, current_aspect, base_url, html)
      current_aspect
    end

    def tag_records(aspect, search)
      map = Hash.new {|h,k| h[k] = []}
      $pagoda.select('tag_aspects') do |rec|
        map[rec[:tag]] << rec[:aspect]
      end
      tags = []
      map.keys.sort.each do |tag|
        aspects = map[tag]
        aspects = [] if aspects[0].nil?
        accept  = false

        if aspect == 'None'
          accept = aspects.empty?
        elsif (aspect == 'All') || aspects.include?(aspect)
          accept = true
        end

        if accept
          if search.empty? || tag.include?(search)
            tags << [tag, aspects]
          end
        end
      end

      tags
    end

    def unbind_link( link_url)
      link_rec = $pagoda.link( link_url)
      return '' if ! link_rec.bound?
      link_rec.unbind
      link_status( link_rec)
    end

    def unchecked_bound_official_website_records
      $pagoda.links do |link|
        link.bound? && link.collation && link.valid? && (link.site == 'Website') && (link.changed != 'N')
      end
    end

    def unchecked_genre_records
      unvisited = []

      $pagoda.games do |game|
        visited = $pagoda.get( 'visited', :key, "unchecked_genres:#{game.id}")
        if visited.empty?
          unvisited << game
        end
      end

      unvisited.sort_by {|rec| rec.id}
    end

    def update_game( params)
      game_rec = $pagoda.game( params[:id])
      if game_rec
        game_rec.update( params)
      else
        $pagoda.create_game( params)
        set_selected_game( params[:id])
      end
    end

    def update_tag( params)
      #p params
      $pagoda.start_transaction
      tag = d(params[:tag])
      $pagoda.delete('tag_aspects',:tag,tag)
      no_aspects = true
      (0..9).each do |i|
        aspect = params["aspect#{i}".to_sym]
        unless aspect.nil? || aspect.empty?
          no_aspects = false
          $pagoda.insert( 'tag_aspects', {:tag => tag, :aspect => d(aspect)})
        end
      end
      if no_aspects
        $pagoda.insert( 'tag_aspects', {:tag => tag, :aspect => ''})
      end
      $pagoda.end_transaction
    end

    def visited_key( key)
      $pagoda.visited_key( key)
    end

    def work_records
      YAML.load(IO.read(ARGV[0] + '/work.yaml')).each_pair do |k,v|
        yield k, v['status'], v['link'], v['values'] unless v['hide']
      end
    end
  end

  helpers EditorHelper
end