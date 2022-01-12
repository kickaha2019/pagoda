#!/bin/csh
#
# Get Dreamhost settings
#
#/Users/peter/Documents/Security/ensure_safe_open.csh
#if ($status != 0) exit 1
#source /Volumes/The*Safe/dreamhost/setup.csh
source ~/Documents/Security/dreamhost/setup.csh

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
# Ensure SSH passphrase in the keychain
#
cd /Users/peter/.ssh
ssh-add -K dreamhost

# -----------------------------------------------------------------
#
# First SFTP pagoda.sql to remote site
#
cd $0:h
cd ../database
sftp $SSH_SERVER <<PUT
put pagoda.sql
PUT
#csh $SB/alofmethbin/ftp_put.csh `pwd`/pagoda.sql pagoda.sql /tmp/ftp_put.log
#cat /tmp/ftp_put.log

# -----------------------------------------------------------------
#
# Secondly load pagoda.sql into the Pagoda MySQL database
# then delete pagoda.sql
#
ssh $SSH_SERVER <<LOAD
mysql -e 'source pagoda.sql' $MYSQLDB alofmethbin_pagoda
rm pagoda.sql
LOAD
#csh $SB/alofmethbin/mysql_load_and_delete.csh pagoda pagoda.sql
