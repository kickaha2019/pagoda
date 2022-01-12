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
ruby ruby/spider.rb database ~/Caches/Pagoda incremental All All
if ($status != 0) exit 1

# Verify the links starting with the oldest verified
date
ruby ruby/verify_links.rb database 1000 ~/Caches/Pagoda/verified 30
if ($status != 0) exit 1

# Search some sites by game name
#date
#ruby ruby/searcher.rb database ~/Caches/Pagoda GooglePlay IOS
date

# Backup current database files
rsync -rvt --delete database ~/temp/Pagoda
if ($status != 0) exit 1

# Compress the database for speed of opening editor
ruby -Iruby ruby/compress_database.rb database
if ($status != 0) exit 1

# -----------------------------------------------------------------
#
# Flag this script has been run
#
touch ~/Synch/PAGODA_OVERNIGHT
