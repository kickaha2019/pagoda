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

# Insist that no outstanding transactions
#if ( -e database/transaction.txt ) then
#  echo Open transactions
#  exit 1
#endif

# Run scanner over everything
#java -Djsse.enableSNIExtension=false -Xmx512M -classpath dist/Pagoda.jar com.alofmethbin.rintrah.Scanner $PAGODA/scripts ~/Caches/Pagoda $PAGODA/database/scan.txt All/Root
#if ($status != 0) exit 1

# Regenerate phrase frequencies
ruby ruby/determine_phrase_frequencies.rb database 50

# Scan Steam GOG etc for games that might match
setenv PATH $PAGODA/ruby:$PATH
ruby ruby/spider.rb database ~/Caches/Pagoda full All All
#if ($status != 0) exit 1

# Merge scan into link table
#ruby ruby/merge_scan_into_link.rb database
#if ($status != 0) exit 1
