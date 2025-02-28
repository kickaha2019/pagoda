require_relative '../pagoda'

class AlignReducedNames
  def initialize( dir)
    @pagoda = Pagoda.release( dir)
  end

  def align(table,key,name_field,reduced_field)
    records = @pagoda.select(table)
    count   = 0

    records.each do |record|
      reduced = Names.reduce(record[name_field])
      if reduced != record[reduced_field]
        count += 1
        @pagoda.start_transaction
        @pagoda.update(table,key,record[key],{reduced_field=>reduced})
        @pagoda.end_transaction
      end
    end

    puts "#{count} names reduced for #{table}"
  end
end

arn = AlignReducedNames.new( ARGV[0])
arn.align('alias',:name,:name,:reduced_name)
arn.align('company',:name,:name,:reduced_name)
arn.align('game',:id,:name,:reduced_name)
arn.align('suggest',:url,:title,:reduced_title)
