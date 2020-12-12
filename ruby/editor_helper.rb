require 'sinatra/base'
require_relative 'database'
require_relative 'names'

module Sinatra
  module EditorHelper
    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 80, alias_rec[:name]) +
      "<label for=\"hide#{index}\">Hidden?</label>" +
      checkbox_element( "hide#{index}", alias_rec[:hide] == 'Y')
    end

    def bind_id( scan_rec)
      binds = $database.get( 'bind', :url, scan_rec[:url])
      return nil if binds.size < 1
      binds[0][:id]
    end

    def bind_scan( scan_id)
      return '' if cookies[:selected_game].nil?
      selected_id = cookies[:selected_game].to_i
      scan_rec = $database.get( 'scan', :id, scan_id)[0]
      return '' if bind_id( scan_rec) == selected_id
      $database.start_transaction
      $database.delete( 'bind', :url, scan_rec[:url])
      $database.insert( 'bind', {
          url:scan_rec[:url],
          id:selected_id
      })
      $database.end_transaction
      'Bound'
    end

    def checkbox_element( name, checked, extras='')
      "<input type=\"checkbox\" id=\"#{name}\" value=\"Y\" #{checked ? 'checked' : ''} #{extras}>"
    end

    def collation_link( scan_id)
      scan_rec = $database.get( 'scan', :id, scan_id)[0]
      binds = $database.get( 'bind', :url, scan_rec[:url])
      game_id = nil

      if binds.size > 0
        game_id = binds[0][:id] if binds[0][:id] >= 0
      else
        game_id = $names.lookup( $database.get( 'scan', :id, scan_id)[0][:name])
      end

      return '' if game_id.nil?
      game_rec = $database.get( 'game', :id, game_id)[0]
      "<a href=\"/game/#{game_rec[:id]}\">#{game_rec[:name]}</a>"
    end

    def combo_box( combo_name, values, current_value, html)
      html << "<td>#{combo_name.capitalize}: "
      html << "<select id=\"#{combo_name}\" onchange=\"change_combo('#{combo_name}')\">"
      values.each do |value|
        selected = (current_value == value) ? 'selected' : ''
        html << "<option value=\"#{value}\"#{selected}>#{value}</option>"
      end
      html << '</select></td>'
    end

    def delete_game( id)
      $database.start_transaction
      $database.delete( 'game',    :id, id)
      $database.delete( 'alias',   :id, id)
      $database.delete( 'bind',    :id, id)
      $names.remove( id)
      $database.end_transaction
    end

    def game_link( id)
      recs = $database.get( 'game', :id, id)
      if (recs.size > 0)
        "<a href=\"/game/#{id}\">#{recs[0][:name]}</a>"
      else
        ''
      end
    end

    def games_records
      search = cookies[:game_search]
      search = '' if search.nil?
      $database.select( 'game') do |rec|
        (rec[:game_type] == 'A') && rec[:name].to_s.downcase.index( search.downcase)
      end
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def ignore_scan( scan_id)
      scan_rec = $database.get( 'scan', :id, scan_id)[0]
      return '' if bind_id( scan_rec) == -1
      $database.start_transaction
      $database.delete( 'bind', :url, scan_rec[:url])
      $database.insert( 'bind', {
          url:scan_rec[:url],
          id:-1
      })
      $database.end_transaction
      'Ignored'
    end

    def input_element( name, len, value, extras='')
      "<input type=\"text\" name=\"#{name}\" maxlength=\"#{len}\" size=\"#{len}\" value=\"#{value}\" #{extras}>"
    end

    def scan_action( rec, action)
      "<button onclick=\"scan_action( #{rec[:id]}, '#{action}');\">#{action.capitalize}</button>"
    end

    def scan_site_combo( combo_name, html)
      values = $database.unique( 'scan', :site)
      values << 'All'
      current_value = cookies[combo_name.to_sym]
      current_value = 'All' unless values.index( current_value)
      combo_box( combo_name, values, current_value, html)
      current_value
    end

    def scan_status( rec)
      if rec[:bind].size > 0
        if rec[:bind][0][:id] >= 0
          'Bound'
        else
          'Ignored'
        end
      elsif $names.lookup( rec[:name])
        'Matched'
      else
        'Unmatched'
      end
    end

    def scan_status_combo( combo_name, current_site, current_type, html)
      values = []
      $database.select( 'scan') do |rec|
        next unless (current_site == 'All') || (current_site == rec[:site])
        next unless (current_type == 'All') || (current_type == rec[:type])
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
      $database.select( 'scan') do |rec|
        next unless (current_site == 'All') || (current_site == rec[:site])
        types << rec[:type]
      end
      types = types.uniq.sort
      types << 'All'
      current_value = cookies[combo_name.to_sym]
      current_value = 'All' unless types.index( current_value)
      combo_box( combo_name, types, current_value, html)
      current_value
    end

    def self.setup
      $database = Database.new( ARGV[0])
      $names     = Names.new
      $database.join( 'scan', :bind, :url, 'bind', :url)
      $database.join( 'game', :aliases, :id, 'alias', :id)

      $database.select( 'game') do |game|
        $names.add( game[:name], game[:id])
        game[:aliases].each do |arec|
          $names.add( arec[:name], game[:id])
        end
      end

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

    def summary_line( site, type, counts, totals, html)
      return if site == ''
      html << "<tr><td>#{site}</td><td>#{type}</td>"
      ['Unmatched', 'Ignored', 'Matched', 'Bound'].each do |status|
        if counts[status] > 0
          html << "<td><a href=\"/scan\" onmousedown=\"set_scan_cookies('#{site}','#{type}','#{status}');\">#{counts[status]}</a></td>"
          totals[status] = 0 if ! totals.has_key?( status)
          totals[status] += counts[status]
        else
          html << "<td>#{counts[status]}</td>"
        end
      end
      html << '</tr>'
    end

    def unbind_scan( scan_id)
      scan_rec = $database.get( 'scan', :id, scan_id)[0]
      return '' if bind_id( scan_rec).nil?
      $database.start_transaction
      $database.delete( 'bind', :url, scan_rec[:url])
      $database.end_transaction
      scan_rec = $database.get( 'scan', :id, scan_id)[0]
      scan_status( scan_rec)
    end

    def update_game( params)
      id = params[:id]
      $database.start_transaction
      $database.delete( 'game',    :id, id)
      $database.delete( 'alias',   :id, id)

      rec = {}
      [:id, :name, :year, :is_group, :group_name, :developer, :publisher, :game_type].each do |field|
        rec[field] = params[field]
      end
      rec[:sort_name] = sort_name( rec[:name])
      $database.insert( 'game', rec)
      $names.add( rec[:name], id)

      (0..20).each do |index|
        name = params["alias#{index}".to_sym]
        next if name.nil? || (name.strip == '')
        rec = {id:id, name:name, hide:params["hide#{index}".to_sym]}
        $database.insert( 'alias', rec)
        $names.add( rec[:name], id)
      end

      $database.end_transaction
    end
  end

  helpers EditorHelper
end