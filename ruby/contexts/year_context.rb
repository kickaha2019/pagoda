# frozen_string_literal: true

class YearContext < DefaultContext
  def initialize(year,sort_by)
    super(sort_by)
    @year = year
  end

  def select_game?(pagoda,game)
    return false if game.group?
    if @year.is_a?(Integer)
      game.year == @year
    else
      game.year.nil? || (game.year < 1900)
    end
  end

  def show_aspect_type(type)
    false
  end
end
