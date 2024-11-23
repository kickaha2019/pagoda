require_relative 'pagoda'

class CompressDatabase
  def initialize( dir, cache)
    @pagoda = Pagoda.release( dir, cache)
  end

  def clean
    @pagoda.clean
  end

  def clean_cache
    @pagoda.clean_cache
  end

  def rebuild
    @pagoda.rebuild
  end
end

gs = CompressDatabase.new( ARGV[0], ARGV[1])
gs.clean
gs.clean_cache
gs.rebuild
