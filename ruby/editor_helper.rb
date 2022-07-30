require 'sinatra/base'
require_relative 'pagoda'
require_relative 'common'

module Sinatra
  module EditorHelper
    include Common

    @@selected_game = -1
    @@today         = Time.now.to_i

    def add_game_from_link( link_url)
      link_rec = $pagoda.link( link_url)
      if collated = link_rec.collation
        return "/game/#{collated.id}"
      end

      #p ['add_game_from_link', link_url]
      g = {:name => link_rec.orig_title, :id => $pagoda.next_value( 'game', :id)}
      begin
        if link_rec.timestamp > 1000
          page = get_cache( link_rec.timestamp)
        else
          page = http_get( link_url)
        end
        $pagoda.get_site_handler( link_rec.site).get_game_details( link_url, page, g)
        $pagoda.create_game( g)
        link_rec.bind( g[:id])
        "/game/#{g[:id]}"
      rescue Exception => bang
        puts( bang.message + "\n" + bang.backtrace.join( "\n"))
        ''
      end
    end

    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 60, alias_rec ? alias_rec.name : '') +
      '</td><td>' +
      checkbox_element( "hide#{index}", alias_rec ? (alias_rec.hide == 'Y') : true)
    end

    def aliases_records( aspect, search)
      games_records( aspect, search).select {|g| g.aliases.size > 0}
    end

    def aspect_element( name, value)
      html = []
      colour, setting = 'white', '?'
      if value == false
        colour, setting = 'red', 'N'
      end
      if value == true
        colour, setting = 'lime', 'Y'
      end
      html = <<"ASPECT_ELEMENT"
<div id="d_#{name}" style="background: #{colour}" onclick="change_aspect( event, '#{name}')">  
<span>#{name}</span>     
<input id="i_#{name}" type="hidden" name="a_#{name}" value="#{setting}">
</div>
ASPECT_ELEMENT
      html.gsub( />\s+</m, '><')
    end

    def aspect_action( aspect, action)
      "<button onclick=\"aspect_action( '#{e(aspect)}', '#{action}');\">#{action.capitalize}</button>"
    end

    def aspect_delete( aspect)
      $pagoda.start_transaction
      $pagoda.delete( 'aspect', :aspect, aspect)
      $pagoda.end_transaction
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

      page = get_cache( link_rec.timestamp)
      site = $pagoda.get_site_handler( link_rec.site)
      site.notify_bind( $pagoda, link_rec, page, bind_game)

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

    def e( text)
      CGI.escape( text)
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
      "<a href=\"/game/#{id}\">#{h(game_rec.name)}</a>"
    end

    def games_by_aspect_records
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
      $pagoda.aspect_names {|aspect| aspects << aspect}
      aspects.sort.collect do |aspect|
        [aspect, $pagoda.aspect_info[aspect]['index'], map[aspect]]
      end + [['None', '', map['None']]]
    end

    def games_records( aspect, search)
      $pagoda.games do |game|
        selected = $pagoda.contains_string( game.name, search)
        game.aliases.each do |a|
          selected = true if $pagoda.contains_string( a.name, search)
        end

        if selected && (aspect != '')
          if aspect == 'None'
            selected = (game.aspects.size == 0)
          else
            selected = game.aspects[aspect]
          end
        end

        selected
      end
    end

    def gather( game_id, gather_url)
      site, type, url = $pagoda.correlate_site( gather_url)
      return "No site found for url" unless site

      game = $pagoda.game( game_id)
      unless $pagoda.has?( 'link', :url, url)
        $pagoda.add_link( site, type, game.title, url)
      end

      link = $pagoda.link( url)
      if link.bound?
        'URL already bound'
      else
        link.bind( game_id)
        ''
      end
    end

    def get_cache( timestamp)
      path = $cache + "/verified/#{timestamp}.html"
      return '' unless File.exist?( path)
      IO.read( path)
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

    def google_search( texts)
      text = texts.join( ' ').downcase.gsub( /[^0-9a-z]/, ' ').gsub( ' ', '+')
      "<a target=\"_blank\" href=\"https://www.google.com/search?q=#{text}\">Google</a>"
    end

    def h(text, max_chars=1000)
      return '' if text.nil?
      text = text[0...max_chars] if text.size > max_chars
      Rack::Utils.escape_html(text)
    end

    def ignore_link( link_url)
      link_rec = $pagoda.link( link_url)
      return '' if bind_id( link_rec) == -1
      link_rec.bind( -1)
      'Ignored'
    end

    def ignored_to_reprieve_records
      recs = []

      $pagoda.links do |link|
        next unless link.status == 'Ignored'
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
      link_lost?(rec) || rec.comment
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

    def link_lost?( rec)
      return false if link_status(rec) == 'Ignored'
      return false if rec.static?
      (rec.timestamp + (90 * 24 * 60 * 60) < @@today)
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

    def links_by_site_and_type( static = false)
      cache = Hash.new {|h,k| h[k] = Hash.new {|h1,k1| h1[k1] = []}}
      $pagoda.links do |rec|
        if rec.static? == static
          cache[rec.site][rec.type] << rec
        end
      end
      cache.keys.sort.each do |site|
        cache[site].keys.sort.each do |type|
          yield site, type, cache[site][type]
        end
      end
    end

    def lost_forget_action( rec)
      "<button onclick=\"delete_expect( '#{e(rec.url)}');\">Forget</button>"
    end

    def lost_revive_action( rec)
      "<button onclick=\"revive_expect( '#{e(rec.url)}');\">Restore</button>"
    end

    def lost_records( site, type)
      $pagoda.lost do |rec|
        chosen = true
        chosen = false unless ((rec.site == site) || (site == 'All'))
        chosen = false unless ((rec.type == type) || (type == 'All'))
        chosen
      end
    end

    def lost_summary
      summary = Hash.new {|h,k| h[k] = Hash.new {|h1,k1| h1[k1] = 0}}
      $pagoda.lost do |rec|
        summary[rec.site][rec.type] += 1
      end
      summary
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

    def problem_link_records( search)
      $pagoda.links do |rec|
        link_flagged?(rec)
      end
    end

    def refresh_metadata
      $pagoda.refresh_reduction_cache
    end

    def reverify( url)
      $pagoda.reverify( url)
    end

    def scan_stats_records
      $pagoda.scan_stats_records {|site, section, count, date| yield site, section, count, date}
    end

    def selected_game
      return '' if @@selected_game < 0
      $pagoda.get( 'game', :id, @@selected_game.to_i)[0][:name]
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
      $pagoda.delete( 'aspect', :id, game_id)
      aspects.each_pair do |a,f|
        $pagoda.insert( 'aspect', {:id => game_id, :aspect => a, :flag => (f ? 'Y' : 'N')})
      end
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
      $pagoda = Pagoda.new( ARGV[0])
      $cache  = ARGV[1]

      $debug = false
      ARGV[2..-1].each do |arg|
        $debug = true if /^debug=true$/i =~ arg
      end
    end

    def sort_name( name)
      name = name.upcase
      if m = /^(A|AN|THE)\s+(.*)$/.match( name)
        m[2]
      else
        name
      end
    end

    def suggest_aspects_records
      recs = $pagoda.select( 'aspect_suggest') do |rec|
        game    = $pagoda.game( rec[:game])
        aspects = game.aspects
        check   = false

        if rec[:aspect]
          rec[:aspect].split(',').each do |aspect|
            check = true if aspects[aspect].nil?
          end
        end

        check
      end

      recs.each do |rec|
        rec[:name] = $pagoda.game( rec[:game]).name
      end
      recs
    end

    def summary_line( site, type, counts, totals, html)
      return if site == ''
      html << "<tr><td>#{h(site)}</td><td>#{type}</td>"

      ['Invalid', 'Free', 'Ignored', 'Bound', 'Flagged'].each do |status|
        c = counts[status]
        colour = (status == 'Free') ? 'lime' : 'white'
        colour = 'cyan' if c[2] > 0
        colour = 'red' if c[1] > 0

        if c[0] > 0
          url = "/links?site=#{e(site)}&type=#{type}&status=#{status}&search=&page=1"
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

    def update_game( params)
      game_rec = $pagoda.game( params[:id])
      if game_rec
        game_rec.update( params)
      else
        $pagoda.create_game( params)
      end
    end

    def visited_key( key)
      $pagoda.visited_key( key)
    end
  end

  helpers EditorHelper
end