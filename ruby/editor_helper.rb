require 'sinatra/base'

module Sinatra
  module EditorHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def scan_line( site, type, unmatched, unbound, matched, bound, html)
      return if site == ''
      html << "<tr><td>#{site}</td><td>#{type}</td><td>#{unmatched}</td><td>#{unbound}</td><td>#{matched}</td><td>#{bound}</td></tr>"
    end

    def site_combo( combo_name, values, html)
      current_value = cookies[combo_name.to_sym]
      current_value = values[0] unless values.index( current_value)
      html << "<td>#{combo_name.capitalize}: "
      html << "<select id=\"#{combo_name}\" onchange=\"site_combo('#{combo_name}')\">"
      values.each do |value|
        selected = (current_value == value) ? 'selected' : ''
        html << "<option value=\"#{value}\"#{selected}>#{value}</option>"
      end
      html << '</select></td>'
      current_value
    end
  end

  helpers EditorHelper
end