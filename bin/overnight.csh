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
date
ruby ruby/scripts/verify_multiple_links.rb database 2250 ~/Caches/Pagoda
if ($status != 0) exit 1

# Suggest some aspects
#date
#ruby ruby/suggest_aspects.rb database ~/Caches/Pagoda 5000 "" ""
#if ($status != 0) exit 1

# Backup current database files
rsync -rvt --delete database ~/temp/Pagoda
if ($status != 0) exit 1

# Compress the database for speed of opening editor
ruby -Iruby ruby/compress_database.rb database ~/Caches/Pagoda
if ($status != 0) exit 1

# -----------------------------------------------------------------
#
# Flag this script has been run
#
touch ~/Synch/PAGODA_OVERNIGHT
