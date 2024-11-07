# frozen_string_literal: true
class PagodaRecord
  def initialize( owner, rec)
    @owner  = owner
    @record = rec
  end

  def generate?
    true
  end

  def method_missing( m, *args, &block)
    if (args.size > 0) || block
      super
    else
      @record[m]
    end
  end

  def record
    @record
  end
end

