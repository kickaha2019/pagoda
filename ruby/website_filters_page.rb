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
<table class="frame">
  <tr><td>Corner</td><td>Title</td><td>Corner</td></tr>
  <tr><td>Side</td><td><div id="#{name}" class="container #{name}"></div></td><td>Side</td></tr>
  <tr><td>Corner</td><td>Bottom</td><td>Corner</td></tr>
</table>
CONTAINER
  end

  def write_drag_script( io)
    io.puts <<"DRAG"
function drag(ev) {
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
    if ( className.test( "include") ) {
      flag = "Y";
    }
    if ( className.test( "exclude") ) {
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
</body>
</html>
FOOTER
  end

  def write_header( io)
    io.puts <<"HEADER1"
<html>
<head>
<style>
.container {background: grey; width: 600px; min-height: 300px}
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
  unused_box.innerHTML = contents.inactive;
}
REFRESH2
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0])
wfp.generate( ARGV[1])
