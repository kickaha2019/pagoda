#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# ruby ruby/verify_links.rb database https://adventuregamers.com/articles/view/poltergeist-treasure ~/Caches/Pagoda/verified
# https://apps.apple.com/app/id1468317913
#ruby ruby/verify_links.rb database 'https://store.steampowered.com/app/1864680' ~/Caches/Pagoda/verified
# ruby ruby/verify_links.rb database 'https://store.steampowered.com/app/303720' ~/Caches/Pagoda/verified
# https://www.gog.com/game/elite_warriors_vietnam
# https://www.gog.com/game/atom_rpg_trudograd
# https://www.uhs-hints.com/uhsweb/vampyre.php
# http://www.gameboomers.com/reviews/Gg/AGoldenWake/AGoldenWake.htm
# https://play.google.com/store/apps/details?id=com.dsfishlabs.bout2en

#ruby ruby/verify_links.rb database 'https://play.google.com/store/apps/details?id=com.dsfishlabs.bout2en' ~/Caches/Pagoda/verified
caffeinate -i ruby ruby/verify_links.rb database 250 ~/Caches/Pagoda/verified
