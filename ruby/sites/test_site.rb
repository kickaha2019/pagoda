require_relative 'default_site'

class TestSite < DefaultSite
	def initialize
		super
		@ran = {}
	end

	def name
		'Test'
	end

	def ran?(method)
		@ran[method.to_sym]
	end

	def find1(scanner, runs)
		@ran[:find1] = true
	end

	def find2(scanner, runs)
		@ran[:find2] = true
	end

	def find3(scanner, runs)
		@ran[:test3] = true
	end
end
