#!/bin/csh
#
# Run Pagoda scanner
#
cd $0:h
cd ..
set PAGODA=`pwd`
set DB=database
#set RINTRAH=Rintrah/dist
#set TEMP=/Users/peter/Pagoda/temp

#
# Clean the cache
#
find ~/Caches/Pagoda -mtime +365 -delete

# Scan Steam GOG etc for games that might match
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/scripts/run_spider.rb database ~/Caches/Pagoda full All All
if ($status != 0) exit 1

# Run the overnight process to verify new links
./bin/overnight.csh
