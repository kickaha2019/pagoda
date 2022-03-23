require_relative 'pagoda'

class DeterminePhraseFrequencies
  def initialize( dir)
    @pagoda = Pagoda.new( dir)
  end

  def analyse
    @phrase_frequencies = Hash.new {|h,k| h[k] = 0}

    @pagoda.games.each do |g|
      o = {}
      @pagoda.string_combos( g.name) do |p,f|
        o[p] = true
        g.aliases.each do |a|
          @pagoda.string_combos(a.name) do |p,f|
            o[p] = true
          end
        end
      end
      o.each_key do |k|
       @phrase_frequencies[k] += 1
      end
    end

    puts "... Analysed #{@phrase_frequencies.size}"
  end

  def deduplicate
    pf, @phrase_frequencies = @phrase_frequencies, {}

    pf.each_pair do |k,v|
      words = k.split( ' ')
      if words.size > 1
        next if pf[words[0..-2].join( ' ')] == v
        next if pf[words[1..-1].join( ' ')] == v
      end
      @phrase_frequencies[k] = v
    end

    puts "... Deduplicated #{@phrase_frequencies.size}"
  end

  def ignore( limit)
    pf, @phrase_frequencies = @phrase_frequencies, {}

    pf.each_pair do |k,v|
      @phrase_frequencies[k] = v if v <= limit
    end

    puts "... Ignored #{@phrase_frequencies.size}"
  end

  def save( path)
    File.open( path, 'w') do |io|
      io.puts "phrase,frequency"
      @phrase_frequencies.each_pair do |k,v|
        io.puts "#{k},#{v}"
      end
    end
  end
end

dwf = DeterminePhraseFrequencies.new( ARGV[0])
dwf.analyse
dwf.ignore( ARGV[1].to_i)
dwf.deduplicate
dwf.save( ARGV[0] + '/phrase_frequencies.csv')
