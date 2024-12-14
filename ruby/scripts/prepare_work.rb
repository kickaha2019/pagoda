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

  def add(label,value,status,link)
    values = [value]
    if @old_work[label]
      values += @old_work[label]['values']
      values = values[0..4]
    end
    @work[label] = {'values' => values, 'status'=> status, 'link' => link}
  end

  def cache_size
    size, status = '???', 'error'
    if system("du -ch -d 0 #{@cache} >/tmp/du.txt")
      size   = IO.readlines('/tmp/du.txt')[-1].strip.split(/\s+/)[0]
      status = 'normal'
    end
    add('Cache size',size,status,nil)
  end

  def run
    cache_size
    unknown_tags
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
    add('Unknown tags',count,(count > 0) ? 'error' : 'normal','/tags?aspect=Unknown')
  end
end

pw = PrepareWork.new(ARGV[0],ARGV[1])
pw.run
pw.save