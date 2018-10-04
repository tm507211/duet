#!/bin/sh

TO=100

DUET="/home/charlie/git_repos/duet"
file="$DUET/patools/test/embed_reg_bench/embed000.struct"
solver="match-embeds"
if ! [ -z "$1" ]; then
  file="$1"
fi

if ! [ -z "$2" ]; then
  solver="$2"
fi

STARTTIME=$(date +"%s%3N")

R1=`timeout $TO "$DUET"/patools.native match-embeds $file`
if echo "$R1" | grep --quiet "Error"; then
    R1="Error"
elif [ "$R1" = "" ]; then
    R1="--"
fi

ENDTIME=$(date +"%s%3N")

echo "\t$R1\t" $(( $ENDTIME - $STARTTIME ))
