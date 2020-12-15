class Names
  def initialize
    @cache    = {}
    @id2reduced  = Hash.new {|h,k| h[k] = []}
    @reduced2ids = Hash.new {|h,k| h[k] = []}
    @id2names    = Hash.new {|h,k| h[k] = []}
    @names2ids   = {}

    # HTML entity codes
    @entities = {
        '&aacute;' => 'a',
        '&amp;'    => '&',
        '&eacute;' => 'e',
        '&egrave;' => 'e',
        '&iuml;'   => 'i',
        '&ocirc;'  => 'o',
        '&quot;'   => '"',
        '&ouml;'   => 'o',
        '&uuml;'   => 'u',
        '&#8216;'  => "'",
        '&#8217;'  => "'",
        '&#8220;'  => '"',
        '&#8221;'  => '"'
    }

    # List of substitutions to make which includes ignoring certain words
    @substitutions = {
        'a'           => '',
        'center'      => 'centre',
        'four'        => '4',
        'five'        => '5',
        'i'           => '1',
        'ii'          => '2',
        'iii'         => '3',
        'in'          => '',
        'iv'          => '4',
        'one'         => '1',
        'redux'       => '',
        'remastered'  => '',
        'review'      => '',
        'six'         => '6',
        'the'         => '',
        'three'       => '3',
        'two'         => '2',
        'v'           => '5',
        'vi'          => '6',
        'vii'         => '7',
        'walkthrough' => ''
    }

    # List of words to ignore if they come before numbers
    @ordinals = [
        'act',
        'book',
        'chapter',
        'episode',
        'vol',
        'volume'
    ]
  end

  def add( name, id)
    name = name.to_s.downcase
    @names2ids[name] =  id
    @id2names[id]    << name

    if m = /^(.*):(.*)$/.match( name)
      add_reduced( reduce( m[1]), id)
      add_reduced( reduce( m[2] + ' ' + m[1]), id)
    end
    add_reduced( reduce(name), id)
  end

  def add_reduced( name, id)
    if m = /^([^0-9]*) ([\d]+) ([^0-9]*)$/.match( name)
      add_reduced( m[1] + ' ' + m[2], id)
      add_reduced( m[1] + ' ' + m[3], id)
    end

    if m = /^(.*) 1$/.match( name)
      add_reduced( m[1], id)
    end

    ids  = @reduced2ids[name]
    ids << id unless ids.index(id)
    names = @id2reduced[id]
    names << name unless names.index( name)
  end

  def check_unique_name( name, id)
    name = name.to_s.downcase
    if @names2ids[name] && (@names2ids[name] != id)
      false
    else
      true
    end
  end

  def keys( id)
    @id2reduced[id]
  end

  def lookup( name)
    ids = @reduced2ids[reduce(name)]
    (ids.size == 1) ? ids[0] : nil
  end

  def matches( name)
    @reduced2ids[reduce(name)]
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

  def remove( id)
    @id2reduced[id].each do |name|
      @reduced2ids[name].delete_if {|nid| nid == id}
    end
    @id2reduced.delete(id)

    @id2names[id].each do |name|
      @names2ids.delete( name)
    end
    @id2names.delete(id)
  end

  def simplify( name)

    # Lower case and decode HTML entities
    reduced = name.to_s.downcase
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
end