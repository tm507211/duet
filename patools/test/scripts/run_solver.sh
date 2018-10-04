#!/bin/sh

FAIL1=0
TO=100

DUET="/home/charlie/git_repos/duet"
DIR="../embed_bench"
SOLVER="match-embeds"
START=0

if ! [ -z "$1" ]; then
    DIR="$1"
fi

if ! [ -z "$2" ]; then
    SOLVER="$2"
fi

if ! [ -z "$3" ]; then
    START="$3"
fi

for file in `ls $DIR/embed*.struct`; do

    NUM=`echo $(basename $file) | sed -e s/[^0-9]//g`
    if [ "$NUM" -lt "$START" ]; then
	continue
    fi

    echo -n $file

    STARTTIME=$(date +"%s%3N")

    R1=`timeout $TO "$DUET"/patools.native "$SOLVER" $file`
    if echo "$R1" | grep --quiet "Error"; then
        FAIL1=$(($FAIL1 + 1))
        R1="Error"
    elif [ "$R1" = "" ]; then
        FAIL1=$(($FAIL1 + 1))
        R1="--"
    fi
    echo -n "\t$R1"

    MIDTIME1=$(date +"%s%3N")

    echo "\t" $(( $MIDTIME1 - $STARTTIME ))
done
echo "Fail1: $FAIL1"
