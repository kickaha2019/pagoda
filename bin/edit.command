#!/bin/csh
#
# Run Pagoda editor
#

# -----------------------------------------------------------------
#
# Check morning import from iMac done
#
set FOUND=`find ~/Synch -name 'MORNING_FROM_IMAC' -ctime -14h | wc -l`
if ("1" != "$FOUND") then
  echo
  echo "*** Morning import from iMac may not have been done"
  echo
  exit
endif

# -----------------------------------------------------------------
#
# Launch the editor
#
cd $0:h
sleep 25;open http://localhost:4567 &
ruby -I../ruby ../ruby/editor.rb ../database /Users/peter/Caches/Pagoda

