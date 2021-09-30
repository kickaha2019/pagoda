require 'sinatra/base'
require_relative 'pagoda'

module Sinatra
  module EditorHelper
    @@selected_game = -1
    @@today         = Time.now.to_i

    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 60, alias_rec ? alias_rec.name : '') +
      '</td><td>' +
      checkbox_element( "hide#{index}", alias_rec ? (alias_rec.hide == 'Y') : true)
    end

    def aliases_records( search)
      games_records( search).select {|g| g.aliases.size > 0}
    end

    def arcade_genres
      ['Adventure',
       'Arcade',
       'Card game',
       'Game',
       'Platformer',
       'Puzzle',
       'Racing',
       'RPG',
       'Shooter',
       'Simulation',
       'Sports',
       'Stealth',
       'Strategy',
       'Word puzzle']
    end

    def arcades_records( search)
      $pagoda.arcades do |arcade|
        $pagoda.contains_string( arcade.name, search)
      end
    end

    def bind_id( link_rec)
      return nil if ! link_rec.bound?
      game_rec = link_rec.collation
      return -1 if game_rec.nil?
      game_rec.id
    end

    def bind_link( link_url)
      return '' if @@selected_game < 0
      link_rec = $pagoda.link( link_url)
      return '' if link_rec.nil?
      return '' if bind_id( link_rec) == @@selected_game
      link_rec.bind( @@selected_game)
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
        defn << "<option value=\"#{e(value)}\"#{selected}>#{h(value)}</option>"
      end
      defn << '</select>'
      html << defn.join('')
    end

    def d( text)
      CGI.unescape( text)
    end

    def delete_arcade( id)
      arcade_rec = $pagoda.arcade( id)
      arcade_rec.delete if arcade_rec != nil
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

    def games_records( search)
      $pagoda.games do |game|
        selected = $pagoda.contains_string( game.name, search)
        game.aliases.each do |a|
          selected = true if $pagoda.contains_string( a.name, search)
        end
        selected
      end
    end

    def get_cache( timestamp)
      IO.read( $cache + "/verified/#{timestamp}.html")
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

    def input_element( name, len, value, extras='')
      "<input type=\"text\" name=\"#{name}\" maxlength=\"#{len}\" size=\"#{len}\" value=\"#{h(value)}\" #{extras}>"
    end

    def link_action( rec, action, row=0)
      "<button onclick=\"link_action( '#{e(e(rec.url))}', '#{action}', #{row});\">#{action.capitalize}</button>"
    end

    def link_records( site, type, status, search)
      $pagoda.links do |rec|
        chosen = rec.name.to_s.downcase.index( search.downcase)
        chosen = false unless ((rec.site == site) || (site == 'All'))
        chosen = false unless (rec.type == type) || (type == 'All')
        if status == 'Flagged'
          chosen = false unless link_lost?(rec) || rec.redirected?
        else
          chosen = false unless (link_status(rec) == status) || (status == 'All')
        end
        chosen
      end
    end

    def link_lost?( rec)
      return false if link_status(rec) == 'Ignored'
      (rec.timestamp + (90 * 24 * 60 * 60) < @@today)
    end

    def link_site_combo( combo_name, current_site, current_type, current_status, html)
      values = $pagoda.links.collect {|s| s.site}.uniq.sort
      values << 'All'
      unless values.index( current_site)
        current_site = 'All'
      end
      base_url = "/links?status=#{current_status}&type=#{current_type}&site="
      combo_box( combo_name, values, current_site, base_url, html)
      current_site
    end

    def link_status( rec)
      rec.status
    end

    def link_status_combo( combo_name, current_site, current_type, current_status, html)
      values = []
      $pagoda.links do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        next unless (current_type == 'All') || (current_type == rec.type)
        values << link_status( rec)
      end
      values = values.uniq.sort
      values << 'All'
      unless values.index( current_status)
        current_status = 'All'
      end
      base_url = "/links?site=#{current_site}&type=#{current_type}&status="
      combo_box( combo_name, values, current_status, base_url, html)
      current_status
    end

    def link_type_combo( combo_name, current_site, current_type, current_status, html)
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
      base_url = "/links?site=#{current_site}&status=#{current_status}&type="
      combo_box( combo_name, types, current_type, base_url, html)
      current_type
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

    def refresh_metadata
      $pagoda.refresh_reduction_cache
    end

    def reverify( url)
      $pagoda.reverify( url)
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

    def summary_line( site, type, counts, totals, html)
      return if site == ''
      html << "<tr><td>#{h(site)}</td><td>#{type}</td>"

      ['Invalid', 'Unmatched', 'Ignored', 'Matched', 'Bound', 'Flagged'].each do |status|
        c = counts[status]
        colour = (status == 'Unmatched') ? 'lime' : 'white'
        colour = 'cyan' if c[2] > 0
        colour = 'red' if c[1] > 0

        if c[0] > 0
          url = "/links?site=#{e(site)}&type=#{type}&status=#{status}&search=&page=1"
          html << "<td style=\"background: #{colour}\"><a href=\"#{url}\">#{c[0]}</a></td>"
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

    def update_arcade( params)
      arcade_rec = $pagoda.arcade( params[:id])
      if arcade_rec
        arcade_rec.update( params)
      else
        $pagoda.create_arcade( params)
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
  end

  helpers EditorHelper
end