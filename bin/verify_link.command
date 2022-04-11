#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH
#ruby ruby/verify_links.rb database 'https://adventuregamers.com/articles/view/whos-lila' ~/Caches/Pagoda/verified
ruby ruby/verify_links.rb database 200 ~/Caches/Pagoda/verified
