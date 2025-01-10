class Names
  def initialize
    @cache       = {}
    @combo2data  = Hash.new {|h,k| h[k] = []}
    @tables      = {}

    # HTML entity codes
    @entities = {
        '&aacute;' => 'a',
        '&amp;'    => '&',
        '&bull;'   => '.',
        '&ccedil;' => 'c',
        '&eacute;' => 'e',
        '&egrave;' => 'e',
        '&gt;'     => '>',
        '&hellip;' => '...',
        '&iacute;' => 'i',
        '&igrave;' => 'i',
        '&iquest;' => '?',
        '&iuml;'   => 'i',
        '&laquo;'  => '"',
        '&lt;'     => '<',
        '&mdash;'  => '-',
        '&nbsp;'   => ' ',
        '&ndash;'  => '-',
        '&ocirc;'  => 'o',
        '&omacr;'  => 'o',
        '&oslash;' => 'o',
        '&ouml;'   => 'o',
        '&quot;'   => '"',
        '&raquo;'  => '"',
        '&reg;'    => ' ',
        '&rsaquo;' => ' ',
        '&trade;'  => ' ',
        '&uacute;' => 'u',
        '&ucirc;'  => 'u',
        '&uuml;'   => 'u',
        '&#xa1;'   => ' ',
        '&#xb0;'   => ' ',
        '&#xbd;'   => ' ',
        '&#xbe;'   => ' ',
        '&#xce;'   => 'l',
        '&#xda;'   => 'u',
        '&#xdf;'   => 's',
        '&#xea;'   => 'e',
        '&#xef;'   => 'l',
        '&#xe0;'   => 'a',
        '&#xe1;'   => 'a',
        '&#xE8;'   => 'e',
        '&#xE9;'   => 'e',
        '&#xeb;'   => 'e',
        '&#xec;'   => 'i',
        '&#xed;'   => 'i',
        '&#xfa;'   => 'u',
        '&#xfb;'   => 'u',
        '&#xfc;'   => 'u',
        '&#xfd;'   => 'y',
        '&#xff;'   => 'y',
        '&#xFF;'   => 'y',
        '&#xff0a;' => ' ',
        '&#xff1c;' => ' ',
        '&#xff1e;' => ' ',
        '&#xf1;'   => 'n',
        '&#x1ce;'  => 'a',
        '&#x101;'  => 'a',
        '&#x14D;'  => 'o',
        '&#x1d0;'  => 'l',
        '&#x22;'   => '"',
        '&#x26;'   => "&",
        '&#x27;'   => "'",
        '&#x2022;' => " ",
        '&#039;'   => "'",
        '&#39;'    => "'",
        '&#8211;'  => "-",
        '&#8216;'  => "'",
        '&#8217;'  => "'",
        '&#8220;'  => '"',
        '&#8221;'  => '"'
    }

    # List of substitutions to make which includes ignoring certain words
    @substitutions = {
        'a'           => '',
        'center'      => 'centre',
        'eight'       => '8',
        'four'        => '4',
        'five'        => '5',
        'i'           => '1',
        'ii'          => '2',
        'iii'         => '3',
        'in'          => '',
        'iv'          => '4',
        'ix'          => '9',
        'license'     => 'licence',
        'nine'        => '9',
        'one'         => '1',
        'redux'       => '',
        'remastered'  => '',
        'review'      => '',
        'seven'       => '7',
        'six'         => '6',
        'the'         => '',
        'three'       => '3',
        'two'         => '2',
        'v'           => '5',
        'vi'          => '6',
        'vii'         => '7',
        'viii'        => '8',
        'vs'          => 'versus',
        'walkthrough' => ''
    }

    # List of words to ignore if they come before numbers
    @ordinals = [
        'act',
        'book',
        'case',
        'chapter',
        'episode',
        'issue',
        'mystery',
        'part',
        'vol',
        'volume'
    ]
  end

  def listen( database, table, name, key)
    @tables[table] = [name, key]
    database.add_listener(table, self)
  end

  def record_deleted( table, record)
    info = @tables[table]
    raise "Unknown table #{table}" unless info
    name = record[info[0]]
    key  = record[info[1]]

    string_combos( name) do |combo|
      entries = @combo2data[combo].select {|data| (data[0] != name) || (data[1] != key)}
      if entries.empty?
        @combo2data.delete(combo)
      else
        @combo2data[combo] = entries
      end
   end
  end

  def record_inserted( table, record)
    info = @tables[table]
    raise "Unknown table #{table}" unless info
    name = record[info[0]]
    key  = record[info[1]]

    string_combos( name) do |combo|
      @combo2data[combo] << [name, key]
    end
  end

  def reduce( name)
    cached = @cache[name]
    return cached if cached

    # Lower case and decode HTML entities
    reduced = simplify( name.gsub(/\(\d\d\d\d\)/, ' '))

    # Apply substitutions and eliminations
    was = nil
    while was != reduced
      was = reduced
      @substitutions.each_pair do |from, to|
        reduced = reduced.gsub( /(^| )#{from}( |$)/, " #{to} ").strip
      end

      @ordinals.each do |ordinal|
        if m = /^(.*) #{ordinal}\s+(\d+.*)$/.match( reduced)
          reduced = m[1] + ' ' + m[2]
        end
      end
    end

    # Compress blanks
    reduced = reduced.gsub( /[ ]+/, ' ').strip

    @cache[name] = reduced
  end

  def simplify( name)

    # Lower case and decode HTML entities
    reduced = name.to_s
    @entities.each_pair do |from, to|
      reduced = reduced.gsub( from, to)
    end
    reduced = reduced.downcase

    # Again for luck
    @entities.each_pair do |from, to|
      reduced = reduced.gsub( from, to)
    end

    # Check for unhandled HTML entity codes
    if m = /(&[a-z0-1#]*;)/.match( reduced)
      puts 'Unhandled HTML entity code: ' + m[1]
    end

    # Specially handle &
    reduced = reduced.gsub( '&', 'and')

    # Replace punctuation by blanks
    reduced.gsub( /[^a-z0-9]/, ' ').strip
  end

  def string_combos( name)
    words = reduce( name).split( ' ')
    yield words.join(' ')

    if words.size > 1
      words.each {|word| yield word}
    end

    if words.size > 2
      (0..(words.size-2)).each do |i|
        yield words[i..(i+1)].join(' ')
      end
    end

    if words.size > 3
      (0..(words.size-3)).each do |i|
        yield words[i..(i+2)].join(' ')
      end
    end

    if words.size > 4
      (0..(words.size-4)).each do |i|
        yield words[i..(i+3)].join(' ')
      end
    end
  end

  def suggest( name, limit)
    id2size = Hash.new {|h,k| h[k] = [1000000, '']}
    string_combos( name) do |combo|
      found = @combo2data[combo]
      found.each do |data|
        text, key = * data
        id2size[key] = [found.size, text] if id2size[key][0] > found.size
      end
    end

    found = id2size.keys.sort_by {|id| id2size[id][0]}
    found[0...limit].each {|id| yield id2size[id][1], id}
  end

  # def suggest_analysis( name)
  #   string_combos( name) do |combo|
  #     ids = @combo2data[combo].collect {|data| data[1]}
  #     yield combo, ids if ids.size > 0
  #   end
  # end
end