#!/bin/csh
#
# Run Pagoda searcher
#

# -----------------------------------------------------------------
#
# Check Google Archive script run
#
set FOUND=`find ~/Synch -name 'ICLOUD_ARCHIVE' -ctime -3h | wc -l`
if ("1" != "$FOUND") then
  echo
  echo "*** iCloud Archive script may not have been run"
  echo
  exit
endif

# -----------------------------------------------------------------
#
# Launch the searching
#
cd $0:h
caffeinate -i overnight.csh
