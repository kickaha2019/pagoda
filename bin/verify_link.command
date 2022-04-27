#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/verify_links.rb database 'https://www.gog.com/game/atom_rpg_trudograd' ~/Caches/Pagoda/verified
#ruby ruby/verify_links.rb database 100 ~/Caches/Pagoda/verified
