#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/verify_links.rb database 'https://apps.apple.com/app/id1457905100' ~/Caches/Pagoda/verified
#ruby ruby/verify_links.rb database 1 ~/Caches/Pagoda/verified
