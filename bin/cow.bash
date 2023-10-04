COW_NUM=$1
QUOTE=$2

cat $QUOTE | /usr/games/cowsay > mystic_cow_${COW_NUM}.txt
