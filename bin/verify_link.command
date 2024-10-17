#!/bin/csh
#
# Run Pagoda verify
#
cd $0:h
cd ..
set PAGODA=`pwd`
setenv PATH $PAGODA/ruby:$PATH

# ruby ruby/verify_links.rb database https://adventuregamers.com/articles/view/poltergeist-treasure ~/Caches/Pagoda
# https://apps.apple.com/app/id1468317913
#ruby ruby/verify_links.rb database 'https://toucharcade.com/2016/11/04/1-bit-rogue-review/' ~/Caches/Pagoda
# ruby ruby/verify_links.rb database 'https://www.metacritic.com/game/pc/the-stanley-parable-ultra-deluxe' ~/Caches/Pagoda
#ruby ruby/verify_links.rb database 'https://store.steampowered.com/app/1809560' ~/Caches/Pagoda
#ruby ruby/verify_links.rb database 'https://store.steampowered.com/app/303720' ~/Caches/Pagoda
# https://www.gog.com/game/elite_warriors_vietnam
# https://www.gog.com/game/atom_rpg_trudograd
# https://www.uhs-hints.com/uhsweb/vampyre.php
# http://www.gameboomers.com/reviews/Gg/AGoldenWake/AGoldenWake.htm
# https://play.google.com/store/apps/details?id=com.dsfishlabs.bout2en
ruby ruby/verify_links.rb database 'https://adventuregamehotspot.com/game/883/49-keys' ~/Caches/Pagoda

#caffeinate -i ruby ruby/verify_links.rb database 10 ~/Caches/Pagoda 320
