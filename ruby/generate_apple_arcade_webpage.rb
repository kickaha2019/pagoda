require_relative 'pagoda'

class AppleArcadeWebpage
  def initialize( dir)
    @games = Pagoda.new( dir).arcades do |arcade|
      ! (arcade.genre.nil? || (arcade.genre == ''))
    end.sort_by {|game| game.name.downcase}

    @dexterities  = ['Easy','Medium','Hard']
    @difficulties = ['Easy','Medium','Hard']
    @depths       = ['Little','Some','Lots']
    @genres       = @games.collect {|g| g.genre}.uniq.sort
    @option       = 0
  end

  def body_filter( code, attribute, values, io)
    io.puts <<"FILTER1"
<TR><TH>#{attribute}</TH><TD>
FILTER1
    values.each_index do |index|
      io.puts <<"FILTER2"
<SPAN ID="#{code}#{@option}" 
ONCLICK="flip( '#{code}#{@option}', #{attribute.downcase}, #{index});" 
CLASS="option">
#{values[index]}
</SPAN>
FILTER2
      @option += 1
    end
    io.puts <<"FILTER3"
</TD></TR>
FILTER3
  end

  def body_filters( io)
    io.puts <<"FILTERS1"
<DIV CLASS="filters">
<DIV ID="filters_hidden">
<DIV CLASS="triangle_right" ONCLICK="hide('filters_hidden');show('filters_shown');"></DIV>
<SPAN ID="filter_status">Filters: all games listed</SPAN>
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
<SPAN CLASS="title">List of Apple Arcade games</SPAN>
<A CLASS="note" HREF="dummy.html">About this page</A>
</DIV>
TITLE
  end

  def declare_flags( name, values, io)
    io.puts "var #{name} = [#{values.collect {'1'}.join(',')}];"
  end

  def declare_values( name, values, io)
    io.puts "var #{name} = [#{values.collect {|v| "\"#{v}\""}.join(',')}];"
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
.header {display:flex; justify-content: space-between;}
.note {}
.title {}
.option {font-size: 30px;
         -moz-user-select: none;
         -webkit-user-select: none;
         -ms-user-select: none;
         user-select: none;
         color: black;
         background-color: yellow;
         border: 1px solid black;
         border-radius: 5px;
         padding: 5px;}
.filters {font-size: 30px; margin-top: 10px}
#filters_hidden {
  display: flex;
}
#filters_shown {
  display: none;
}
.triangle_down {
  display: inline-block;
	width: 0;
	height: 0;
	border-left: 10px solid transparent;
	border-right: 10px solid transparent;
	border-top: 20px solid #555;
  margin-top: 7px;
  margin-right: 10px;
}
.triangle_right {
  display: inline-block;
	width: 0;
	height: 0;
	border-top: 10px solid transparent;
	border-left: 20px solid #555;
	border-bottom: 10px solid transparent;
  margin-top: 7px;
  margin-right: 10px;
}
.filter_control {font-size: 40px; cursor: pointer}
</STYLE>
<SCRIPT>
var inactive = new Object();
var activeCount = #{options_count};

function flip( oid, flags, index) {
  s1 = document.getElementById( oid).style;
  if (flags[index] == 1) {
    flags[index] = 0;
    activeCount -= 1;
    s1.backgroundColor = 'lightgray';
  } else {
    flags[index] = 1;
    s1.backgroundColor = 'yellow';
    activeCount += 1;
  }
  fs = document.getElementById( 'filter_status');
  if (activeCount < #{number_of_filters}) {
    fs.innerHTML = 'Filters: some games not shown';
  } else {
    fs.innerHTML = 'Filters: all games listed';
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
function list_all() {
  listing = ['<TABLE><TR><TH>Name</TH><TH>Dexterity</TH><TH>Difficulty</TH><TH>Depth</TH><TH>Genre</TH></TR>'];
FUNCTION_ALL1

    @games.each do |arcade|
      dex = (['Varied'] + @dexterities).index(  arcade.dexterity)
      dif = (['Varied'] + @difficulties).index( arcade.difficulty)
      dep = @depths.index( arcade.depth)
      gen = @genres.index( arcade.genre)
      next if dex.nil? || dif.nil? || dep.nil? || gen.nil?

      io.puts <<"FUNCTION_ALL2"
    list_one( '#{arcade.name.gsub( "'", "\\'")}', '#{arcade.url}', #{dex}, #{dif}, #{dep}, #{gen});
FUNCTION_ALL2
   end

    io.puts <<"FUNCTION_ALL3"
  listing.push( '</TABLE>');  
  document.getElementById( 'list').innerHTML = listing.join('');
}
FUNCTION_ALL3
  end

  def list_one_function( io)
    io.puts <<"FUNCTION1"
function list_one( name, url, dex, dif, dep, gen) {
  if ((dex > 0) && (!  dexterity[dex-1])) {return;}
  if ((dif > 0) && (! difficulty[dif-1])) {return;}
  if (! depth[dep]) {return;}
  if (! genre[gen]) {return;}
  listing.push( '<TR><TD><A HREF="' + url + '">' + name + '</A></TD>');
  listing.push( '<TD>' + dexterities[dex] + '</TD>');
  listing.push( '<TD>' + difficulties[dif] + '</TD>');
  listing.push( '<TD>' + depths[dep] + '</TD>');
  listing.push( '<TD>' + genres[gen] + '</TD></TR>');
}
FUNCTION1
  end

  def number_of_filters
    @difficulties.size + @dexterities.size + @depths.size + @genres.size
  end

  def options_count
    9 + @genres.size
  end

  def today
    Time.now.strftime( '%d %b %Y')
  end
end

g = AppleArcadeWebpage.new( ARGV[0])
File.open( ARGV[1], 'w') do |io|
  g.html_header( io)
  g.body_title( io)
  g.body_filters( io)
  g.body_list( io)
  g.html_footer( io)
end