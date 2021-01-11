require 'sinatra/base'
require_relative 'pagoda'

module Sinatra
  module EditorHelper
    @@variables = {}

    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 60, alias_rec ? alias_rec.name : '') +
      '</td><td>' +
      checkbox_element( "hide#{index}", alias_rec ? (alias_rec.hide == 'Y') : true)
    end

    def aliases_records
      games_records(:alias_search).select {|g| g.aliases.size > 0}
    end

    def bind_id( scan_rec)
      return nil if ! scan_rec.bound?
      game_rec = scan_rec.collation
      return -1 if game_rec.nil?
      game_rec.id
    end

    def bind_scan( scan_id)
      return '' if get_variable(:selected_game).nil?
      selected_id = get_variable(:selected_game).to_i
      scan_rec = $pagoda.scan( scan_id)
      return '' if bind_id( scan_rec) == selected_id
      scan_rec.bind( selected_id)
      'Bound'
    end

    def check_name( name, id)
      $pagoda.check_unique_name( name, id) ? 'Y' : 'N'
    end

    def checkbox_element( name, checked, extras='')
      "<input type=\"checkbox\" name=\"#{name}\" value=\"Y\" #{checked ? 'checked' : ''} #{extras}>"
    end

    def collation( scan_id)
      collation = $pagoda.scan( scan_id).collation
      return {'link':'','year':''} if collation.nil?
      {'link':"<a href=\"/game/#{collation.id}\">#{collation.name}</a>",'year':"#{collation.year}"}
    end

    def collation_year( scan_id)
      collation = $pagoda.scan( scan_id).collation
      collation.nil? ? '' : collation.year
    end

    def combo_box( combo_name, values, current_value, html)
      defn = ["#{combo_name.capitalize}:&nbsp;"]
      defn << "<select id=\"#{combo_name}\" onchange=\"change_combo('#{combo_name}')\">"
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

    def delete_game( id)
      game_rec = $pagoda.game( id)
      game_rec.delete if game_rec != nil
    end

    def delete_expect( url)
      $pagoda.delete_expect( url)
    end

    def e( text)
      CGI.escape( text)
    end

    def game_group_action()
      "<button onclick=\"set_group(); return false;\">Set</button>"
    end

    def game_link( id)
      game_rec = $pagoda.game( id)
      return '' if game_rec.nil?
      "<a href=\"/game/#{id}\">#{h(game_rec.name)}</a>"
    end

    def games_records( search_cookie=:game_search)
      search = get_variable(search_cookie)
      search = '' if search.nil?
      $pagoda.games do |game|
        selected = $pagoda.contains_string( game.name, search)
        game.aliases.each do |a|
          selected = true if $pagoda.contains_string( a.name, search)
        end
        selected
      end
    end

    def get_variable( name, defval=nil)
      @@variables[name.to_sym] ? @@variables[name.to_sym] : defval
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def ignore_scan( scan_id)
      scan_rec = $pagoda.scan( scan_id)
      return '' if bind_id( scan_rec) == -1
      scan_rec.bind( -1)
      'Ignored'
    end

    def input_element( name, len, value, extras='')
      "<input type=\"text\" name=\"#{name}\" maxlength=\"#{len}\" size=\"#{len}\" value=\"#{h(value)}\" #{extras}>"
    end

    def lost_forget_action( rec)
      "<button onclick=\"delete_expect( '#{e(rec.url)}');\">Forget</button>"
    end

    def lost_revive_action( rec)
      "<button onclick=\"revive_expect( '#{e(rec.url)}');\">Restore</button>"
    end

    def lost_records
      chosen_site   = get_variable(:site,'All')
      chosen_type   = get_variable(:type,'All')

      $pagoda.lost do |rec|
        chosen = true
        chosen = false unless ((h(rec.site) == chosen_site) || (chosen_site == 'All'))
        chosen = false unless (rec.type == chosen_type) || (chosen_type == 'All')
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

    def revive_expect( url)
      $pagoda.revive_expect( url)
    end

    def scan_action( rec, action)
      "<button onclick=\"scan_action( #{rec.id}, '#{action}');\">#{action.capitalize}</button>"
    end

    def scan_records
      search = get_variable(:scan_search)
      search = '' if search.nil?

      chosen_site   = d(get_variable(:site,'All'))
      chosen_type   = get_variable(:type,'All')
      chosen_status = get_variable(:status,'All')

      $pagoda.scans do |rec|
        chosen = rec.name.to_s.downcase.index( search.downcase)
        chosen = false unless ((rec.site == chosen_site) || (chosen_site == 'All'))
        chosen = false unless (rec.type == chosen_type) || (chosen_type == 'All')
        chosen = false unless (scan_status(rec) == chosen_status) || (chosen_status == 'All')
        chosen
      end
    end

    def scan_site_combo( combo_name, html)
      values = $pagoda.scans.collect {|s| s.site}.uniq.sort
      values << 'All'
      current_value = d(get_variable(combo_name,'All'))
      unless values.index( current_value)
        set_variable(combo_name.to_sym, current_value = 'All')
      end
      combo_box( combo_name, values, current_value, html)
      current_value
    end

    def scan_status( rec)
      if rec.bound?
        rec.collation ? 'Bound' : 'Ignored'
      elsif rec.collation
        'Matched'
      else
        'Unmatched'
      end
    end

    def scan_status_combo( combo_name, current_site, current_type, html)
      values = []
      $pagoda.scans do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        next unless (current_type == 'All') || (current_type == rec.type)
        values << scan_status( rec)
      end
      values = values.uniq.sort
      values << 'All'
      current_value = get_variable(combo_name,'All')
      unless values.index( current_value)
        set_variable( combo_name, current_value = 'All')
      end
      combo_box( combo_name, values, current_value, html)
      current_value
    end

    def scan_type_combo( combo_name, current_site, html)
      types = []
      $pagoda.scans do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        types << rec.type
      end
      types = types.uniq.sort
      types << 'All'
      current_value = get_variable( combo_name,'All')
      unless types.index( current_value)
        set_variable( combo_name, current_value = 'All')
      end
      combo_box( combo_name, types, current_value, html)
      current_value
    end

    def selected_game
      id = get_variable(:selected_game)
      id ? $pagoda.get( 'game', :id, id.to_i)[0][:name] : ''
    end

    def set_variable( name, value)
      @@variables[name.to_sym] = value
    end

    def self.setup
      $pagoda = Pagoda.new( ARGV[0])

      $debug = false
      ARGV[1..-1].each do |arg|
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

    def summary_line( site, type, counts, totals, lost, html)
      return if site == ''
      html << "<tr><td>#{h(site)}</td><td>#{type}</td>"

      if type == ''
        count = 0
        lost.each_value {|ls| ls.each_value {|lt| count += lt}}
        lost[site][type] = count
      end

      if lost[site][type] > 0
        html << "<td style=\"background: red\"><a href=\"/lost\" onmousedown=\"set_scan_cookies('#{e(site)}','#{type}','#{status}');\">#{lost[site][type]}</a></td>"
      else
        html << "<td></td>"
      end

      ['Unmatched', 'Ignored', 'Matched', 'Bound'].each do |status|
        colour = (status == 'Unmatched') ? 'red' : 'white'
        if counts[status] > 0
          html << "<td style=\"background: #{colour}\"><a href=\"/scan\" onmousedown=\"set_scan_cookies('#{e(site)}','#{type}','#{status}');\">#{counts[status]}</a></td>"
          totals[status] = 0 if ! totals.has_key?( status)
          totals[status] += counts[status]
        else
          html << "<td></td>"
        end
      end
      html << '</tr>'
    end

    def unbind_scan( scan_id)
      scan_rec = $pagoda.scan( scan_id)
      return '' if ! scan_rec.bound?
      scan_rec.unbind
      scan_status( scan_rec)
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