require 'erb'
require_relative 'pagoda'

class WebsiteFiltersPage
  def initialize( dir, templates)
    @pagoda    = Pagoda.new( dir)
    @aspects   = YAML.load( IO.read( dir + '/aspects.yaml'))
    @templates = templates

    seen = {}
    @aspects.each_pair do |name, info|
      next unless info['index']
      raise "Duplicate index for aspect #{name}" if seen[info['index'].to_i]
      seen[info['index'].to_i] = true
    end

    @aspects.each_pair do |name, info|
      unless info['index']
        free = -1
        (0..100).each do |i|
          unless seen[i]
            free = i
            break
          end
        end
        raise "No index for aspect #{name} suggest #{free}"
      end
    end
  end

  def aspect_name_indexes
    @aspects.each_pair do |name, info|
      yield name, info['index']
    end
  end

  def generate( output_dir)
    aspects    = @aspects
    containers = ['include', 'unused', 'exclude']

    aspects_section = template( 'aspects').result( binding)
    filters_section = template( 'filters').result( binding)
    welcome_section = template( 'welcome').result( binding)

    File.open( output_dir + '/index.html', 'w') do |io|
      io.print template('index').result( binding)
    end

    # File.open( output_dir + '/aspects.html', 'w') do |io|
    #   aspects    = @aspects
    #   io.print @aspects_template.result( binding)
    # end
    #
    # File.open( output_dir + '/filters.html', 'w') do |io|
    #   aspects    = @aspects
    #   containers = ['include', 'unused', 'exclude']
    #   io.print @filters_template.result( binding)
    # end
  end

  def template( name)
    ERB.new( IO.read( @templates + '/' + name + '.erb'))
  end
end

wfp = WebsiteFiltersPage.new( ARGV[0], ARGV[1])
wfp.generate( ARGV[2])
