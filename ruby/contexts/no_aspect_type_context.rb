# frozen_string_literal: true

class NoAspectTypeContext < DefaultContext
  def initialize(type,sort_by)
    super(sort_by)
    @type = type
  end

  def select_game?(pagoda,game)
    return false if game.group?
    aspects     = game.aspects
    return false if aspects['Lost']

    game.aspects.each_pair do |a, flag|
      return false if flag && (pagoda.get('aspect',:name,a)[0][:type] == @type)
    end

    true
  end

  def show_aspect_type(type)
    type == @type
  end
end
