require_relative 'pagoda'

class WebsiteFiltersPage
  def initialize( dir)
    @pagoda  = Pagoda.new( dir)
    @aspects = YAML.load( IO.read( dir + '/aspects.yaml'))

    seen = {}
    @aspects.each_pair do |name, info|
      raise "No index for aspect #{name}" unless info['index']
      raise "Duplicate index for aspect #{name}" if seen[info['index'].to_i]
      seen[info['index'].to_i] = true
    end
  end

  def button( name, info, status)
    return <<"BUTTON"
<div class="button #{status}" 
     draggable="true"
     ondragstart="drag( event, #{info['index']})" 
     ondragover="event.preventDefault()"
     ondrop="drop(event)">#{name}</div>
BUTTON
  end

  def generate( output_file)
    File.open( output_file, 'w') do |io|
      write_header( io)
      write_container( 'Include', 'include', io)
      write_container( 'Unused',  'unused',  io)
      write_container( 'Exclude', 'exclude', io)
      write_footer( io)
    end
  end

  def write_container( title, name, io)
    io.puts <<"CONTAINER"
<div class="frame2">
  <div class="frame1">
    <div id="#{name}" class="container #{name}" 
         ondragover="event.preventDefault()" ondrop="drop(event)"></div>
  </div>
  <div class="title"><div></div><span>#{title}</span><div></div></div>
</div>
CONTAINER
  end

  def write_drag_script( io)
    io.puts <<"DRAG"
function drag(ev,index) {
    ev.dataTransfer.setData("index", index);
}
DRAG
  end

  def write_drop_script( io)
    io.puts <<"DROP"
function drop(ev) {
    ev.preventDefault();
    var index = ev.dataTransfer.getData("index");
    var flag = '';
    var className = ev.target.className;
    if ( className.includes( "include") ) {
      flag = "Y";
    }
    if ( className.includes( "exclude") ) {
      flag = "N";
    }
    window.localStorage.setItem( "pagoda.aspect." + index, flag);
    refresh();
}
DROP
  end

  def write_footer( io)
    io.puts <<"FOOTER"
<script>
refresh();
</script>
</div>
</body>
</html>
FOOTER
  end

  def write_header( io)
    io.puts <<"HEADER1"
<html>
<head>
<style>
.page {margin-left: auto; margin-right: auto; width: 690px}
.container {background: grey; width: 600px; min-height: 300px}
.frame1 {padding: 20px; border: 5px solid blue}
.frame2 {padding: 20px; margin-top: 10px; position: relative}
.title {position: absolute; top: 15px; left: 45px; display: flex; width: 600px}
.title div {background: blue; border-top: 5px solid white; border-bottom: 5px solid white; 
            flex-grow: 1; height: 5px}
.title span {font-size: 20px; color: blue; background: white; position: relative; top: -5px; left: 0px;
             padding-left: 10px; padding-right: 10px}
.button {display: inline-block; border: 1px solid black; border-radius: 5px; background: cyan; font-size: 18px;
         margin: 3px;}
</style>
<script>
HEADER1
    write_drag_script( io)
    write_drop_script( io)
    write_refresh_script( io)
    io.puts <<"HEADER2"
</script>
</head>
<body>
<div class="page">
HEADER2
  end

  def write_refresh_script( io)
    io.puts <<"REFRESH1"
function make_button( name, index, status) {
  return '<div class="button ' + status + '"' +
         ' draggable="true"' +
         ' ondragstart="drag( event, ' + index + ')"' + 
         ' ondragover="event.preventDefault()"' +
         ' ondrop="drop(event)">' +name + '</div>';
}

function add_button( name, index, contents) {
  var flag = window.localStorage.getItem( "pagoda.aspect." + index);
  var status = 'ignore';
  if (flag == 'Y') {status = 'include';}
  if (flag == 'N') {status = 'exclude';}
  button = make_button( name, index, status);
  if (flag == 'Y') {
    contents.included = contents.included + button;
  }
  else if (flag == 'N') {
    contents.excluded = contents.excluded + button;
  }
  else {
    contents.unused = contents.unused + button;
  }
}

function refresh() {
  const contents = {excluded:'', included:'', unused: ''};
REFRESH1
    @aspects.each_pair do |name, info|
      io.puts "add_button( '#{name}', #{info['index']}, contents);"
    end
    io.puts <<"REFRESH2"
  var excluded_box = document.getElementById( "exclude");
  excluded_box.innerHTML = contents.excluded;
  var included_box = document.getElementById( "include");
  included_box.innerHTML = contents.included;
  var unused_box = document.getElementById( "unused");
  unused_box.innerHTML = contents.unused;
}
REFRESH2
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0])
wfp.generate( ARGV[1])
