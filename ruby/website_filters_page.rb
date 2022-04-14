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

  def generate( output_file)
    File.open( output_file, 'w') do |io|
      write_header( io)
      write_footer( io)
    end
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
REFRESH1
    @aspects.each_pair do |name, info|
      io.puts <<"REFRESH_ASPECT"
  var flag = window.localStorage.getItem( "pagoda.aspect.#{info['index']}");
  var button = "<button onclick=\"link_bind_action( '#{e(e(rec.url))}', #{game_id});\">Bind</button>""
REFRESH_ASPECT
    end
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0])
wfp.generate( ARGV[1])
