require 'nokogiri'

class Nodes
  def initialize( set)
    @set = set
  end

  def css( expr)
    results = []
    @set.each do |node|
      node[0].css( expr).each do |result|
        if block_given?
          got = yield result, * node[1..-1]
          #p ['css1', got]
          if got
            results << [result, * got]
          end
        else
          results << [result, * node[1..-1]]
        end
      end
    end
    #p ['css', results.size]
    Nodes.new( results)
  end

  def self.parse( page)
    Nodes.new( [[Nokogiri::HTML( page).root.at_xpath( '//body')]])
  end

  def parent( up = 1)
    results = @set
    (1..up).each do
      results, results1 = [], results
      results1.each do |node|
        parent = node[0].parent
        #p parent.name
        if block_given?
          got = yield parent, * node[1..-1]
          if got
            results << [parent, * got]
          end
        else
          results << [parent, * node[1..-1]]
        end
      end
    end

    # results = []
    # @set.each do |node|
    #   parent = node[0].parent
    #   #p parent.name
    #   if block_given?
    #     got = yield parent, * node[1..-1]
    #     if got
    #       results << [parent, * got]
    #     end
    #   else
    #     results << [parent, * node[1..-1]]
    #   end
    # end
    #p ['parent', results.size]
    Nodes.new( results)
  end
end
