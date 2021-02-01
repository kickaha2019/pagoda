=begin
	Search sites by game name

  Command line:
		Database directory
		Cache directory
		How many games to search for in each site
		One or more sites to search
=end

require_relative 'common'

class Searcher
	include Common

	def initialize( dir, cache)
		@dir          = dir
		@cache        = cache
		@pagoda       = Pagoda.new( dir)
	end

	def search( dir, max_searches)
		site_cache_dir = @cache + '/' + dir
		newest, time = 0, 0

		Dir.entries( site_cache_dir).each do |f|
			if m = /^(\d+\.json$)/.match( f)
				t = File.mtime( site_cache_dir + '/' + f).to_i
				if t > time
					newest, time = m[1].to_i, t
				end
			end
		end

		max_game_id, looped = 0, false
		@pagoda.games.each do |game|
			max_game_id = game.id if game.id > max_game_id
		end

		while max_searches > 0
			newest += 1

			if newest > max_game_id
				return if looped
				looped = true
				newest = 0
				next
			end

			unless @pagoda.has?( 'game', :id, newest)
				next
			end

			max_searches -= 1
			game = @pagoda.game( newest)
			urls = yield game.name

			game.aliases.each do |a|
				urls += yield a.name
			end

			File.open( "#{site_cache_dir}/#{newest}.json", 'w') do |io|
				io.puts urls.to_json
			end
		end
	end
end

searcher = Searcher.new( ARGV[0], ARGV[1])

ARGV[3..-1].each do |site_name|
  require_relative searcher.to_filename( site_name)
  site = Kernel.const_get( site_name).new
	searcher.search( site.cache_directory, ARGV[2].to_i) do |game_name|
    site.search( game_name)
	end
end
