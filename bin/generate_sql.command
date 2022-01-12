#!/bin/csh
#
# Generate SQL for upload
#
cd $0:h
cp ~/Pagoda/database/pagoda.sql ~/Pagoda/database/pagoda.sql.old
ruby -I../ruby ../ruby/generate_sql.rb ../database ~/Pagoda/database/pagoda.sql

