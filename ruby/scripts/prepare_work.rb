require_relative '../database'
require_relative '../pagoda'

class PrepareWork
  def initialize(dir,cache)
    @pagoda = Pagoda.release(dir,cache)
    @cache  = cache
    @path   = dir + '/work.yaml'
    if File.exist? @path
      @old_work = YAML.load_file(@path)
    else
      @old_work = {}
    end
    @work = {}
  end

  def add(label,value,status,link,hide=false)
    values = [value]
    if @old_work[label]
      values += @old_work[label]['values']
      values = values[0..4]
    end
    @work[label] = {'values' => values,
                    'status' => status,
                    'link'   => link,
                    'hide'   => hide}
  end

  def cache_size
    size, status = '???', 'error'
    if system("du -cm -d 0 #{@cache} >/tmp/du.txt")
      size   = IO.readlines('/tmp/du.txt')[-1].strip.split(/\s+/)[0]
      status = 'normal'
    end
    add('Cache size (MB)',size,status,nil)
  end

  def free_links
    count = 0
    @pagoda.links.each do |link|
      count += 1 if link.status == 'Free'
    end
    add('Free links',count,'warning','/links?status=Free',count == 0)
  end

  def flagged_links
    count = 0
    @pagoda.links do |link|
      count += 1 if link.comment
    end
    add('Flagged links',count,'warning','/links?status=Flagged',count == 0)
  end

  def missing_aspect_type(type)
    aspect_info = @pagoda.aspect_info
    count       = 0

    @pagoda.games do |game|
      next if game.group?

      selected = ! game.aspects['Lost']
      game.aspects.each_pair do |a, flag|
        if flag && (aspect_info[a]['type'] == type)
          selected = false
        end
      end

      count += 1 if selected
    end

    add("Games with no #{type}",count,'error',"/games?no_aspect_type=#{type}&sort_by=id",count == 0)
  end

  def no_genre
    missing_aspect_type('genre')
  end

  def no_perspective
    missing_aspect_type('perspective')
  end

  def no_year
    count = 0
    @pagoda.games do |game|
      count += 1 unless game.year
    end
    add('Games with no year',count,'error',"/games?year=&sort_by=id",count == 0)
  end

  def oldest_link
    oldest = Time.now.to_i
    @pagoda.links do |link|
      next if link.timestamp <= 100
      oldest = link.timestamp if link.timestamp < oldest
    end
    add('Oldest link in days',(Time.now.to_i - oldest) / (24 * 60 * 60),'normal',nil)
  end

  def run
    cache_size
    oldest_link
    unknown_tags
    free_links
    flagged_links
    no_year
    no_genre
    no_perspective
  end

  def save
    File.open(@path, 'w') do |io|
      io.puts @work.to_yaml
    end
  end

  def unknown_tags
    count = 0
    @pagoda.select('tag_aspects') do |rec|
      count += 1 if rec[:aspect] == 'Unknown'
    end
    add('Unknown tags',count,(count > 0) ? 'error' : 'normal','/tags?aspect=Unknown',count == 0)
  end
end

pw = PrepareWork.new(ARGV[0],ARGV[1])
pw.run
pw.save