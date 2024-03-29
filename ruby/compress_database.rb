require_relative 'pagoda'

class CompressDatabase
  def initialize( dir)
    @pagoda = Pagoda.new( dir)
  end

  def clean
    @pagoda.clean
  end

  def rebuild
    @pagoda.rebuild
  end
end

gs = CompressDatabase.new( ARGV[0])
gs.clean
gs.rebuild
