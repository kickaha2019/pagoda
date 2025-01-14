# frozen_string_literal: true

class CompanyContext < DefaultContext
  def initialize(company,sort_by)
    super(sort_by)
    @company = company
  end

  def select_game?(pagoda,game)
    return false if game.group?
    aspects = game.aspects
    return false if aspects['Lost']
    if @company
      (game.developer == company) || (game.publisher == company)
    else
      game.developer.nil? || game.publisher.nil?
    end
  end
end
