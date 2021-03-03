require 'sinatra/base'
require_relative 'pagoda'

module Sinatra
  module EditorHelper
    @@variables            = {}
    @@today                = Time.now.to_i

    def alias_element( index, alias_rec)
      input_element( "alias#{index}", 60, alias_rec ? alias_rec.name : '') +
      '</td><td>' +
      checkbox_element( "hide#{index}", alias_rec ? (alias_rec.hide == 'Y') : true)
    end

    def aliases_records
      games_records(:alias_search).select {|g| g.aliases.size > 0}
    end

    def bind_id( link_rec)
      return nil if ! link_rec.bound?
      game_rec = link_rec.collation
      return -1 if game_rec.nil?
      game_rec.id
    end

    def bind_link( link_url)
      return '' if get_variable(:selected_game).nil?
      selected_id = get_variable(:selected_game).to_i
      link_rec = $pagoda.link( link_url)
      return '' if link_rec.nil?
      return '' if bind_id( link_rec) == selected_id
      link_rec.bind( selected_id)
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
      return {'link':'','year':''} if link.nil?
      collation = link.collation
      return {'link':'','year':''} if collation.nil?
      link_html = "<a title=\"#{p(collation.name)}\" href=\"/game/#{collation.id}\">#{h(collation.name,40)}</a>"
      {'game':collation.id, 'link':link_html,'year':"#{collation.year}"}
    end

    def collation_year( link_url)
      collation = $pagoda.link( link_url).collation
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

    def delete_link( link_url)
      link_rec = $pagoda.link( link_url)
      link_rec.delete if link_rec
      'Deleted'
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

    def get_cache( timestamp)
      IO.read( $cache + "/verified/#{timestamp}.html")
    end

    def get_variable( name, defval=nil)
      @@variables[name.to_sym] ? @@variables[name.to_sym] : defval
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

    def link_records
      search = get_variable(:link_search)
      search = '' if search.nil?

      chosen_site   = d(get_variable(:site,'All'))
      chosen_type   = get_variable(:type,'All')
      chosen_status = get_variable(:status,'All')

      $pagoda.links do |rec|
        chosen = rec.name.to_s.downcase.index( search.downcase)
        chosen = false unless ((rec.site == chosen_site) || (chosen_site == 'All'))
        chosen = false unless (rec.type == chosen_type) || (chosen_type == 'All')
        chosen = false unless (link_status(rec) == chosen_status) || (chosen_status == 'All')
        chosen
      end
    end

    def link_site_combo( combo_name, html)
      values = $pagoda.links.collect {|s| s.site}.uniq.sort
      values << 'All'
      current_value = d(get_variable(combo_name,'All'))
      unless values.index( current_value)
        set_variable(combo_name.to_sym, current_value = 'All')
      end
      combo_box( combo_name, values, current_value, html)
      current_value
    end

    def link_status( rec)
      lost = (rec.timestamp + (90 * 24 * 60 * 60) < @@today)

      if rec.bound?
        rec.collation ? (lost ? 'Lost' : 'Bound') : 'Ignored'
      elsif lost
        'Lost'
      elsif rec.collation
        'Matched'
      else
        'Unmatched'
      end
    end

    def link_status_combo( combo_name, current_site, current_type, html)
      values = []
      $pagoda.links do |rec|
        next unless (current_site == 'All') || (current_site == rec.site)
        next unless (current_type == 'All') || (current_type == rec.type)
        values << link_status( rec)
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

    def link_type_combo( combo_name, current_site, html)
      types = []
      $pagoda.links do |rec|
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

    def lost_forget_action( rec)
      "<button onclick=\"delete_expect( '#{e(rec.url)}');\">Forget</button>"
    end

    def lost_revive_action( rec)
      "<button onclick=\"revive_expect( '#{e(rec.url)}');\">Restore</button>"
    end

    def lost_records
      chosen_site = d( get_variable(:site,'All'))
      chosen_type = get_variable(:type,'All')

      $pagoda.lost do |rec|
        chosen = true
        chosen = false unless ((rec.site == chosen_site) || (chosen_site == 'All'))
        chosen = false unless ((rec.type == chosen_type) || (chosen_type == 'All'))
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

    def p(text)
      return '' if text.nil?
      text.gsub( /["'<>&]/, ' ')
    end

    def refresh_metadata
      $pagoda.refresh_reduction_cache
    end

    def reverify( url)
      $pagoda.reverify( url)
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

      ['Lost', 'Unmatched', 'Ignored', 'Matched', 'Bound'].each do |status|
        colour = ['Unmatched', 'Lost'].include?(status) ? 'red' : 'white'
        if counts[status] > 0
          html << "<td style=\"background: #{colour}\"><a href=\"/links\" onmousedown=\"set_link_cookies('#{e(site)}','#{type}','#{status}');\">#{counts[status]}</a></td>"
          totals[status] = 0 if ! totals.has_key?( status)
          totals[status] += counts[status]
        else
          html << "<td></td>"
        end
      end
      html << '</tr>'
    end

    def unbind_link( link_url)
      link_rec = $pagoda.link( link_url)
      return '' if ! link_rec.bound?
      link_rec.unbind
      link_status( link_rec)
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