# frozen_string_literal: true

class AspectContext < DefaultContext
  def initialize(aspect,sort_by)
    super(sort_by)
    @aspect = aspect
  end

  def select_game?(pagoda,game)
    return false if game.group?

    if @aspect == 'None'
      game.aspects.size == 0
    else
      game.aspects[aspect]
    end
  end
end
