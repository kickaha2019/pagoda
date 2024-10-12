require 'net/http'
require 'net/https'
require 'uri'
require_relative '../pagoda'

class ReplaceAspects
  def initialize(database)
    @pagoda  = Pagoda.new(database)
    @aspects = @pagoda.aspect_info
  end

  def find_games_with_aspect(aspect)
    found = []
    @pagoda.select( 'aspect') do |rec|
      if rec[:aspect] == aspect
        game = @pagoda.game(rec[:id])
        found << [game, (rec[:flag] == 'Y'), game.aspects]
      end
    end

    found.each do |tuple|
      yield tuple[0], tuple[1], tuple[2]
    end
  end

  def replace_aspects(game,aspects)
    @pagoda.start_transaction
    @pagoda.delete( 'aspect', :id, game.id)
    aspects.each_pair do |aspect, flag|
      @pagoda.insert( 'aspect',
                      {:id => game.id,
                               :aspect => aspect,
                               :flag => flag ? 'Y' : 'N'})
    end
    @pagoda.end_transaction
  end

  def validate_aspect(name)
    unless @aspects.has_key?(name)
      raise "Unknown aspect: #{name}"
    end
  end
end

ra = ReplaceAspects.new ARGV[0]
ARGV[1..-1].each do |arg|
  ra.validate_aspect arg
end

ra.find_games_with_aspect(ARGV[1]) do |game,flag,aspects|
  puts "Replacing aspect #{ARGV[1]} for game #{game.name}"
  aspects.delete ARGV[1]
  ARGV[2..-1].each do |arg|
    aspects[arg] = flag
  end
  ra.replace_aspects game,aspects
end
