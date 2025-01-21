#!/bin/csh
#
# Run Pagoda verify and search
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# Compress the database for speed of opening editor
caffeinate -i ruby -Iruby ruby/compress_database.rb database ~/Caches/Pagoda
