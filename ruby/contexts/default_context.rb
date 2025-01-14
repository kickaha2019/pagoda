# frozen_string_literal: true

class DefaultContext
  def initialize(sort_by='name')
    @sort_by = sort_by
  end

  def select_game?(pagoda,game)
    true
  end

  def show_aspect_type(type)
    true
  end

  def sort_games(games)
    games.sort_by do |rec|
      (@sort_by == 'id') ? rec.id : rec.name.to_s
    end
  end
end
