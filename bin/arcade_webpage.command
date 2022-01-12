#!/bin/csh
#
# Generate Apple Arcade webpage for upload
#
cd $0:h
ruby -I../ruby ../ruby/generate_apple_arcade_webpage.rb ../database ~/Caches/Pagoda/apple_arcade ~/temp/Sites/Articles/Games/Apple_Arcade/list.html

