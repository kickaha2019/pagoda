class Names
  def initialize
    @cache     = {}
    @combo2ids = Hash.new {|h,k| h[k] = []}
    @id2names  = Hash.new {|h,k| h[k] = []}
    @names2ids = {}

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
        '&igrave;' => 'i',
        '&iuml;'   => 'i',
        '&laquo;'  => '"',
        '&lt;'     => '<',
        '&mdash;'  => '-',
        '&nbsp;'   => ' ',
        '&ndash;'  => '-',
        '&ocirc;'  => 'o',
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

  def add( name, id)
    name = name.to_s.downcase
    id   = id.to_i
    @names2ids[name] =  id
    @id2names[id]    << name

    string_combos( name) do |combo|
      @combo2ids[combo] << id
    end
  end

  def check_unique_name( name, id)
    name = name.to_s.downcase
    id   = id.to_i
    if @names2ids[name] && (@names2ids[name] != id)
      false
    else
      true
    end
  end

  def rarity( name)
    freq = 1000000

    string_combos( name) do |combo|
      ids = @combo2ids[combo]
      freq = ids.size if ids.size < freq
    end

    freq
  end

  def reduce( name)
    # if /Girl Who/ =~ name.to_s
    #   puts "DEBUG100"
    # end

    cached = @cache[name]
    return cached if cached

    # Lower case and decode HTML entities
    reduced = simplify( name)

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

  def remove( name, id)
    id = id.to_i
    string_combos( reduce( name)) do |combo|
      @combo2ids[combo].delete( id)
    end

    @names2ids.delete( name)
    @id2names.delete(id)
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
    words.each {|word| yield word}

    (0..(words.size-2)).each do |i|
      yield words[i..(i+1)].join(' ')
    end

    (0..(words.size-3)).each do |i|
      yield words[i..(i+2)].join(' ')
    end

    (0..(words.size-4)).each do |i|
      yield words[i..(i+3)].join(' ')
    end
  end

  def suggest( name, limit)
    found = nil

    string_combos( name) do |combo|
      ids = @combo2ids[combo]
      found = ids if found.nil? || (ids.size < found.size)
    end

    if found
      found = found[0..limit]
      found.each {|id| yield id}
    end
  end
end