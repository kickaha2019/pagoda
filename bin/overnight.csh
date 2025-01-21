#!/bin/csh
#
# Run Pagoda verify and search
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# Scan for new links on some sites
date
ruby ruby/scripts/run_spider.rb database ~/Caches/Pagoda overnight
if ($status != 0) exit 1

# Verify the links starting with the oldest verified
csh bin/verify.csh
if ($status != 0) exit 1
