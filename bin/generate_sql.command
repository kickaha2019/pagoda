#!/bin/csh
#
# Generate SQL for upload
#
cd $0:h
cp ~/Pagoda/database/pagoda.sql ~/Pagoda/database/pagoda.sql.old
ruby -I../ruby ../ruby/generate_sql.rb ../database ~/Pagoda/database/pagoda.sql
if ($status != 0) exit 1

# As a bonus generate aspect search webpage
cd ..
set PAGODA=`pwd`
ruby ruby/generate_aspect_webpage.rb database ~/Caches/Pagoda ruby/templates ~/Sites/Games/aspects_database
