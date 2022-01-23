#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/verify_links.rb database 'http://www.brawsome.com.au/blog/index.php/games/jolly-rover/' ~/Caches/Pagoda/verified
