require 'sinatra/base'
require_relative 'pagoda'

module Sinatra
  module EditorHelper
    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 80, alias_rec ? alias_rec.name : '') +
      "&nbsp;&nbsp;<label for=\"hide#{index}\">Hidden?</label>" +
      checkbox_element( "hide#{index}", alias_rec ? (alias_rec.hide == 'Y') : false)
    end

    def bind_id( scan_rec)
      return nil if ! scan_rec.bound?
      game_rec = scan_rec.collation
      return -1 if game_rec.nil?
      game_rec.id
    end

    def bind_scan( scan_id)
      return '' if cookies[:selected_game].nil?
      selected_id = cookies[:selected_game].to_i
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

    def collation_link( scan_id)
      collation = $pagoda.scan( scan_id).collation
      return '' if collation.nil?
      "<a href=\"/game/#{collation.id}\">#{collation.name}</a>"
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

    def game_link( id)
      game_rec = $pagoda.game( id)
      return '' if game_rec.nil?
      "<a href=\"/game/#{id}\">#{h(game_rec.name)}</a>"
    end

    def games_records
      search = cookies[:game_search]
      search = '' if search.nil?
      $pagoda.games do |game|
        if game.game_type != 'A'
          false
        else
          selected = game.name.to_s.downcase.index( search.downcase)
          game.aliases.each do |a|
            selected = true if a.name.to_s.downcase.index( search.downcase)
          end
          selected
        end
      end
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

    def lost_action( rec)
      "<button onclick=\"delete_expect( '#{e(rec.url)}');\">Forget</button>"
    end

    def lost_records
      chosen_site   = cookies[:site]
      chosen_type   = cookies[:type]
      chosen_status = cookies[:status]

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

    def scan_action( rec, action)
      "<button onclick=\"scan_action( #{rec.id}, '#{action}');\">#{action.capitalize}</button>"
    end

    def scan_records
      search = cookies[:scan_search]
      search = '' if search.nil?

      chosen_site   = d(cookies[:site])
      chosen_type   = cookies[:type]
      chosen_status = cookies[:status]

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
      current_value = d(cookies[combo_name.to_sym])
      current_value = 'All' unless values.index( current_value)
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
      current_value = cookies[combo_name.to_sym]
      current_value = 'All' unless values.index( current_value)
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
      current_value = cookies[combo_name.to_sym]
      current_value = 'All' unless types.index( current_value)
      combo_box( combo_name, types, current_value, html)
      current_value
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