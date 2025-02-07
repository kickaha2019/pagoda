require_relative '../common'
require_relative '../database'
require_relative '../pagoda'
require_relative '../contexts/default_context'
require_relative '../contexts/aspect_context'
require_relative '../contexts/no_aspect_type_context'
require_relative '../contexts/year_context'
require_relative '../contexts/company_context'

class PrepareWork
  include Common

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
      values = values[0..30]
    end
    @work[label] = {'values' => values,
                    'status' => status,
                    'link'   => link,
                    'hide'   => hide}
  end

  def copy(label)
    if @old_work[label]
      @work[label] = @old_work[label]
      @work[label]['hide'] = true
    end
  end

  def cache_size
    size, status = '???', 'error'
    if system("du -cm -d 0 #{@cache} >/tmp/du.txt")
      size   = IO.readlines('/tmp/du.txt')[-1].strip.split(/\s+/)[0]
      status = 'normal'
    end
    add('Cache size (MB)',size,status,nil)
  end

  def collations
    label = 'Collated links'
    count = 0
    last  = @old_work[label] ? @old_work[label]['values'][0] : 1000000
    @pagoda.links do |link|
      count += 1 if link.collation
    end
    add(label,count,(count >= last) ? 'normal' : 'error',nil)
  end

  def context_find(context, label, url)
    count       = 0

    @pagoda.games do |game|
      count += 1 if context.select_game?(@pagoda, game)
    end

    add(label, count, 'error', url, count == 0)
  end

  def flagged_links
    count = 0
    @pagoda.links do |link|
      count += 1 if link.comment
    end
    add('Flagged links',count,'error','/links?status=Flagged',count == 0)
  end

  def free_links
    count = 0
    @pagoda.links.each do |link|
      count += 1 if link.status == 'Free'
    end
    add('Free links',count,'warning','/links?status=Free',count == 0)
  end

  def missing_aspect_type(type)
    context_find( NoAspectTypeContext.new(type,:id),
                  "Games with no #{type}",
                  "/games?no_aspect_type=#{type}&sort_by=id")
  end

  def no_company
    context_find( CompanyContext.new(nil,:id),
                  "Games with no company",
                  "/games?company=&sort_by=id")
  end

  def no_genre
    missing_aspect_type('genre')
  end

  def no_perspective
    missing_aspect_type('perspective')
  end

  def no_year
    context_find( YearContext.new(nil,:id),
                  "Games with no year",
                  "/games?year=&sort_by=id")
  end

  def oldest_link
    oldest = nil
    @pagoda.links do |link|
      next if link.timestamp <= 100
      next if link.static?
      oldest = link if oldest.nil? || (link.timestamp < oldest.timestamp)
    end
    if oldest.nil?
      add('Oldest link', '','normal',nil)
    else
      add('Oldest link', Time.at(oldest.timestamp).strftime('%Y-%m-%d'),'normal',
          "/link/#{e(e(oldest.url))}")
    end
  end

  def redundant_ignores
    count = 0

    ignored = {}
    @pagoda.select('bind') do |bind|
      ignored[bind[:url]] = true if bind[:id] < 0
    end

    @pagoda.links do |link|
      next unless ignored[link.url]
      digest = link.get_digest
      count += 1 if @pagoda.reject_link?(link, digest)
    end

    add('Redundant ignores', count, 'warning', nil, count == 0)
  end

  def run
    collations
    cache_size
    scans
    #redundant_ignores
    oldest_link
    unknown_tags
    free_links
    flagged_links
    no_year
    no_company
    no_genre
    no_perspective
    unknown_companies
  end

  def save
    File.open(@path, 'w') do |io|
      io.puts @work.to_yaml
    end
  end

  def scans
    @pagoda.settings['overnight'].each do |scan|
      key = "Scan: #{scan['site']} / #{scan['type']} / #{scan['method']}"

      run_last_night = false
      @pagoda.select('history') do |history|
        if (history[:site]   == scan['site']) &&
           (history[:type]   == scan['type']) &&
           (history[:method] == scan['method']) &&
           ((Time.now.to_i - 18 * 60 * 60) < history[:timestamp])
          run_last_night  = true
          add(key,
              history[:elapsed],
              'warning',
              nil,
              history[:elapsed] / (scan['every'] ? scan['every'] : 1) < 120)
        end
      end

      unless run_last_night
        copy key
      end
    end
  end

  def unknown_companies
    unknown, known = {}, {}
    @pagoda.select('company') do |rec|
      known[rec[:name]] = true
    end
    @pagoda.select('company_alias') do |rec|
      known[rec[:alias]] = true
    end

    @pagoda.select('bind') do |bind|
      next if bind[:id] < 0
      @pagoda.get('link',:url,bind[:url]).each do |link|
        digest = @pagoda.get_digest(link)
        ['developers','publishers'].each do |key|
          (digest[key] || []).each do |company|
            company = company.strip
            next if company.empty? || ['-'].include?(company)
            unknown[company] = true unless known[company]
          end
        end
      end
    end

    File.open(ARGV[1] + '/unknown_companies.txt', 'w') do |io|
      io.puts unknown.keys.sort.join("\n")
    end

    add('Unknown companies',unknown.size,'warning',
        "/companies?known=N", unknown.empty?)
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