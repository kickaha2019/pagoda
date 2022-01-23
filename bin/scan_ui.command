#!/bin/csh
#
# Run Pagoda scanner
#
cd $0:h
cd ..
set PAGODA=`pwd`
set DB=database
set RINTRAH=Rintrah/dist
#set TEMP=/Users/peter/Pagoda/temp

# Run scanner over everything
java -Djsse.enableSNIExtension=false -Xmx512M -classpath $RINTRAH/rintrah.jar com.alofmethbin.rintrah.Scanner $PAGODA/scripts ~/Caches/Pagoda $PAGODA/database/scan1.txt
