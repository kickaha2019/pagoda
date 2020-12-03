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
  end

  helpers EditorHelper
end