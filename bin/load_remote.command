#!/bin/csh
#
# Get Hostgator settings
#
source ~/Documents/Security/hostgator/setup.csh
if ($status != 0) exit 1

# -----------------------------------------------------------------
#
# Check database SQL generated recently
#
set FOUND=`find ~/Pagoda/database -name 'pagoda.sql' -ctime -48h | wc -l`
if ("1" != "$FOUND") then
  echo
  echo "*** Database SQL needs to be generated"
  echo
  exit
endif

# -----------------------------------------------------------------
#
# First SFTP pagoda.sql to remote site
#
cd $0:h
cd ../database
$SFTP $SERVER <<PUT
put pagoda.sql
PUT

# -----------------------------------------------------------------
#
# Secondly load pagoda.sql into the Pagoda MySQL database
# then delete pagoda.sql
#
$SSH $SERVER <<LOAD
mysql -e 'source pagoda.sql' $PAGODA_DB
rm pagoda.sql
LOAD
