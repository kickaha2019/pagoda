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
      write_footer( io)
    end
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
function refresh() {
  var excluded = '';
  var included = '';
  var inactive = '';
  var flag     = '';
  var button   = '';
REFRESH1
    @aspects.each_pair do |name, info|
      io.puts <<"REFRESH_ASPECT"
  flag = window.localStorage.getItem( "pagoda.aspect.#{info['index']}");
  status = 'ignore';
  if (flag == 'Y') {status = 'include';}
  if (flag == 'N') {status = 'exclude';}
  button = #{button( name, info, status)};
  if (flag == 'Y') {
    included = included + button;
  }
  else if (flag == 'N') {
    excluded = excluded + button;
  }
  else {
    inactive = inactive + button;
  }
REFRESH_ASPECT
      io.puts <<"REFRESH2"
   var excluded_box = document.getElementById( "excluded");
   excluded_box.innerHTML = excluded;
   var included_box = document.getElementById( "included");
   included_box.innerHTML = included;
   var unused_box = document.getElementById( "inactive");
   unused_box.innerHTML = inactive;
}
REFRESH2
    end
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0])
wfp.generate( ARGV[1])
