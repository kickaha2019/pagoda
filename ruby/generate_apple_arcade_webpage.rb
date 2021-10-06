require_relative 'pagoda'
require_relative 'common'

class AppleArcadeWebpage
  include Common

  def initialize( dir, cache)
    @games = Pagoda.new( dir).arcades do |arcade|
      ! (arcade.genre.nil? || (arcade.genre == ''))
    end.sort_by {|game| game.name.downcase}

    @dexterities  = ['Easy','Medium','Hard']
    @difficulties = ['Easy','Medium','Hard']
    @depths       = ['Little','Some','Lots']
    @genres       = @games.collect {|g| g.genre}.uniq.sort
    @option       = 0
    @cache        = cache
    @errors       = 0
  end

  def body_filter( code, attribute, values, io)
    io.puts <<"FILTER1"
<TR><TH>#{attribute}:</TH><TD><DIV CLASS="options">
FILTER1
    values.each_index do |index|
      io.puts <<"FILTER2"
<SPAN ID="#{code}#{@option}" 
ONCLICK="flip( '#{code}#{@option}', #{attribute.downcase}, #{index});" 
CLASS="option">
#{values[index].upcase}
</SPAN>
FILTER2
      @option += 1
    end
    io.puts <<"FILTER3"
</DIV></TD></TR>
FILTER3
  end

  def body_filters( io)
    io.puts <<"FILTERS1"
<DIV CLASS="filters">
<DIV ID="filters_hidden">
<DIV CLASS="triangle_right" ONCLICK="hide('filters_hidden');show('filters_shown');"></DIV>
<SPAN ID="filter_status">Filters</SPAN>
</DIV>
<DIV ID="filters_shown">
<DIV CLASS="triangle_down" ONCLICK="hide('filters_shown');show('filters_hidden');"></DIV>
<TABLE>
FILTERS1

    body_filter( 'a', 'Dexterity',  @dexterities,  io)
    body_filter( 'b', 'Difficulty', @difficulties, io)
    body_filter( 'c', 'Depth',      @depths,       io)
    body_filter( 'd', 'Genre',      @genres,       io)

    io.puts <<"FILTERS2"
</TABLE>
</DIV>
</DIV>
FILTERS2
  end

  def body_list( io)
    io.puts <<BODY_LIST
<DIV ID="list"></DIV>
<SCRIPT>
list_all();
</SCRIPT>
BODY_LIST
  end

  def body_title( io)
    io.puts <<"TITLE"
<DIV CLASS="header">
<SPAN CLASS="note">Generated #{today}</SPAN>
<SPAN ID="title" CLASS="title">List of Apple Arcade games</SPAN>
<A CLASS="note" HREF="dummy.html">About this page</A>
</DIV>
TITLE
  end

  def check_for_errors
    if @errors > 0
      puts "!!! #{@errors} errors in run"
      exit 1
    end
  end

  def check_name( arcade, ember_json)
    return unless ember_json['name']
    if arcade.name != ember_json['name'].gsub( '®', '&reg;').gsub( '™', '&trade;')
      error( "Name mismatch for #{arcade.name} / #{ember_json['name']}")
    end
  end

  def declare_flags( name, values, io)
    io.puts "var #{name} = [#{values.collect {'1'}.join(',')}];"
  end

  def declare_values( name, values, io)
    io.puts "var #{name} = [#{values.collect {|v| "\"#{v}\""}.join(',')}];"
  end

  def e(text)
    return '' if text.nil?
    text.gsub( "'", "&#39;")
  end

  def error( msg)
    puts "!!!  #{msg}"
    @errors += 1
  end

  def extract_ember_json( url, html)
    html.split("\n").each do |line|
      if m = /^\s*<script[^>]*>({.*)$/.match( line)
        return JSON.parse( m[1])
      end
    end
    raise "Failed to find ember json in #{url}"
  end

  def get_ember_json( arcade)
    if /\.com\/app\// =~ arcade.url
      apple_page = http_get_cached( @cache, arcade.url, 45 * 24 * 60 * 60)
      extract_ember_json( arcade.url, apple_page)
    else
      {}
    end
  end

  def get_platforms( arcade, ember_json)
    ember_json['operatingSystem']
  end

  def html_footer( io)
    io.puts <<"FOOTER"
</BODY>
</HTML>
FOOTER
  end

  def html_header( io)
    io.puts <<"HEADER1"
<HTML>
<HEAD>
<STYLE>
body {background-color: #242424}
.header {display:flex; justify-content: space-between;}
.note {font-size: 25px; color: #BFBFBF;}
.title {font-size: 30px; font-weight: bold; color: #BFBFBF;}
#list {
  display: flex;
  justify-content: center;
}

table {
  font-size: 20px;
  color: white;
}

#list table {
  font-size: 25px;
  border-collapse: collapse; 
}

td, th {padding: 8px}
table a {color: white}
table a:visited {color: white}

#list td, #list th {border-left: 1px solid white}
#list th {border-bottom: 1px solid white}
#list td:nth-child(1), #list th:nth-child(1) {border-left: 0px}

#list tr:nth-child(even) td {background: #1C1C1C}
#list tr:nth-child(odd)  td {background: #3D3D3D}

.option {font-size: 15px;
         -moz-user-select: none;
         -webkit-user-select: none;
         -ms-user-select: none;
         user-select: none;
         color: blue;
         background-color: white;
         border-radius: 8px;
         padding: 3px;
         padding-left: 15px;
         padding-right: 15px;
         margin: 5px;
}
.options {display: flex; flex-wrap: wrap;}
.filters {font-size: 25px; margin-top: 5px; color: white}
#filters_hidden {
  display: flex;
}
#filters_shown {
  display: none;
}
#filters_shown th:nth-child(1) {text-align: left;}
#filter_status {font-weight: bold; margin-top: 16px;}

.triangle_down {
  display: inline-block;
	width: 0;
	height: 0;
	border-left: 8px solid transparent;
	border-right: 8px solid transparent;
	border-top: 16px solid cyan;
  margin-top: 19px;
  margin-right: 10px;
}
.triangle_right {
  display: inline-block;
	width: 0;
	height: 0;
	border-top: 8px solid transparent;
	border-left: 16px solid cyan;
	border-bottom: 8px solid transparent;
  margin-top: 20px;
  margin-right: 10px;
}
.filter_control {font-size: 40px; cursor: pointer}
</STYLE>
<SCRIPT>
var inactive = new Object();

function flip( oid, flags, index) {
  s1 = document.getElementById( oid).style;
  if (flags[index] == 1) {
    flags[index] = 0;
    s1.backgroundColor = '#888';
  } else {
    flags[index] = 1;
    s1.backgroundColor = 'white';
  }
  list_all();
}
function hide( cname) {
  document.getElementById( cname).style.display = 'none';
}
function show( cname) {
  document.getElementById( cname).style.display = 'flex';
}
HEADER1

    declare_flags( 'dexterity',  @dexterities,  io)
    declare_flags( 'difficulty', @difficulties, io)
    declare_flags( 'depth',      @depths,       io)
    declare_flags( 'genre',      @genres,       io)

    declare_values( 'dexterities', ['Varied'] + @dexterities, io)
    declare_values( 'difficulties', ['Varied'] + @difficulties, io)
    declare_values( 'depths', @depths, io)
    declare_values( 'genres', @genres, io)

    list_one_function( io)
    list_all_function( io)

    io.puts <<"HEADER2"
</SCRIPT>
</HEAD>
<BODY>
HEADER2
  end

  def list_all_function( io)
    io.puts <<"FUNCTION_ALL1"
var listing = [];
var total = 0;
var count = 0;
function list_all() {
  listing = ['<TABLE><TR><TH>Name</TH>',
             '<TH>Dexterity</TH>',
             '<TH>Difficulty</TH>',
             '<TH>Depth</TH>',
             '<TH>Genre</TH></TR>'];
  total = 0;
  count = 0;
FUNCTION_ALL1

    @games.each do |arcade|
      begin
        ember_json = get_ember_json( arcade)
        check_name( arcade, ember_json)
        dex = (['Varied'] + @dexterities).index(  arcade.dexterity)
        dif = (['Varied'] + @difficulties).index( arcade.difficulty)
        dep = @depths.index( arcade.depth)
        gen = @genres.index( arcade.genre)
        next if dex.nil? || dif.nil? || dep.nil? || gen.nil?

        io.puts <<"FUNCTION_ALL2"
      list_one( '#{e(arcade.name)}', '#{arcade.url}', #{dex}, #{dif}, #{dep}, #{gen});
FUNCTION_ALL2
      rescue Exception => bang
        error( "#{bang.message} for #{arcade.name}")
      end
   end

    io.puts <<"FUNCTION_ALL3"
  listing.push( '</TABLE>');  
  document.getElementById( 'list').innerHTML = listing.join('');
  document.getElementById( 'title').innerHTML = count + ' out of ' + total + ' Apple Arcade games';
}
FUNCTION_ALL3
  end

  def list_one_function( io)
    io.puts <<"FUNCTION1"
function list_one( name, url, dex, dif, dep, gen) {
  total += 1;
  if ((dex > 0) && (!  dexterity[dex-1])) {return;}
  if ((dif > 0) && (! difficulty[dif-1])) {return;}
  if (! depth[dep]) {return;}
  if (! genre[gen]) {return;}
  listing.push( '<TR><TD><A TARGET=“_blank” REL=“nofollow” HREF="' + url + '">' + name + '</A></TD>');
  listing.push( '<TD>' + dexterities[dex] + '</TD>');
  listing.push( '<TD>' + difficulties[dif] + '</TD>');
  listing.push( '<TD>' + depths[dep] + '</TD>');
  listing.push( '<TD>' + genres[gen] + '</TD></TR>');
  count += 1;
}
FUNCTION1
  end

  def number_of_filters
    @difficulties.size + @dexterities.size + @depths.size + @genres.size
  end

  def today
    Time.now.strftime( '%d %b %Y')
  end
end

g = AppleArcadeWebpage.new( ARGV[0], ARGV[1])
File.open( ARGV[2], 'w') do |io|
  g.html_header( io)
  g.body_title( io)
  g.body_filters( io)
  g.body_list( io)
  g.html_footer( io)
end
g.check_for_errors