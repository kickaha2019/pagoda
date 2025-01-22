#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# Verify the links starting with the oldest verified
date
ruby ruby/scripts/verify_multiple_links.rb database 1000 ~/Caches/Pagoda
if ($status != 0) exit 1

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
