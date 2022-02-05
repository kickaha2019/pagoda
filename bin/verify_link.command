#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/verify_links.rb database 'https://store.steampowered.com/app/1170820' ~/Caches/Pagoda/verified
