#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/verify_links.rb database 'https://apps.apple.com/app/id1456188526' ~/Caches/Pagoda/verified
