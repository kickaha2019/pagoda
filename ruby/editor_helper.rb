require 'sinatra/base'

module Sinatra
  module EditorHelper
    def combo_box( combo_name, values, current_value, html)
      html << "<td>#{combo_name.capitalize}: "
      html << "<select id=\"#{combo_name}\" onchange=\"change_combo('#{combo_name}')\">"
      values.each do |value|
        selected = (current_value == value) ? 'selected' : ''
        html << "<option value=\"#{value}\"#{selected}>#{value}</option>"
      end
      html << '</select></td>'
    end

    def games_records
      search = cookies[:game_search]
      search = '' if search.nil?
      $database.select( 'game') do |rec|
        (rec[:game_type] == 'A') && rec[:name].to_s.index( search)
      end
    end

    def h(text)
      Rack::Utils.escape_html(text)
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
      elsif rec[:collate].size > 0
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

    def summary_line( site, type, unmatched, ignored, matched, bound, html)
      return if site == ''
      html << "<tr><td>#{site}</td><td>#{type}</td><td>#{unmatched}</td><td>#{ignored}</td><td>#{matched}</td><td>#{bound}</td></tr>"
    end
  end

  helpers EditorHelper
end