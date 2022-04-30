#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# https://apps.apple.com/app/id1468317913
# https://store.steampowered.com/app/1387150
# https://www.gog.com/game/elite_warriors_vietnam
# https://www.gog.com/game/atom_rpg_trudograd
# https://www.uhs-hints.com/uhsweb/vampyre.php
# http://www.gameboomers.com/reviews/Gg/AGoldenWake/AGoldenWake.htm

ruby ruby/verify_links.rb database 'https://www.gog.com/game/blake_stone_planet_strike' ~/Caches/Pagoda/verified
#ruby ruby/verify_links.rb database 100 ~/Caches/Pagoda/verified
