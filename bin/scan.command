#!/bin/csh
#
# Run Pagoda scanner
#
cd $0:h
#if (-e ../database/transaction.txt) then
#  echo "*** Outstanding transactions"
#	exit 1
#endif
caffeinate -i scan.csh
