#!/bin/sh

TO=1

DUET="/home/charlie/git_repos/duet"
file="$DUET/patools/test/embed_reg_bench/embed000.struct"
if ! [ -z "$1" ]; then
  file="$1"
fi

res="--"

R1=`timeout $TO "$DUET"/patools.native match-embeds $file`
if echo "$R1" | grep --quiet "Error"; then
    R1="Error"
elif [ "$R1" = "" ]; then
    R1="--"
else
    res="$R1"
fi
echo -n "\t$R1"

R2=`timeout $TO "$DUET"/patools.native crypto-mini-sat $file`
if echo "$R2" | grep --quiet "Error"; then
    R2="Error"
elif [ "$R2" = "" ]; then
    R2="--"
else
    res="$R2"
fi
echo -n "\t$R2"

R3=`timeout $TO "$DUET"/patools.native lingeling $file`
if echo "$R3" | grep --quiet "Error"; then
    R3="Error"
elif [ "$R3" = "" ]; then
    R3="--"
else
    res="$R3"
fi
echo -n "\t$R3"

R4=`timeout $TO "$DUET"/patools.native haifacsp $file`
if echo "$R4" | grep --quiet "Error"; then
    R4="Error"
elif [ "$R4" = "" ]; then
    R4="--"
else
    res="$R4"
fi
echo -n "\t$R4"

R5=`timeout $TO "$DUET"/patools.native gecode $file`
if echo "$R5" | grep --quiet "Error"; then
    R5="Error"
elif [ "$R5" = "" ]; then
    R5="--"
else
    res="$R5"
fi
echo -n "\t$R5"

R6=`timeout $TO "$DUET"/patools.native vf2 $file`
if echo "$R6" | grep --quiet "Error"; then
    R6="Error"
elif [ "$R6" = "" ]; then
    R6="--"
else
    res="$R6"
fi
echo -n "\t$R6"

R7=`timeout $TO "$DUET"/patools.native ortools $file`
if echo "$R7" | grep --quiet "Error"; then
    R7="Error"
elif [ "$R7" = "" ]; then
    R7="--"
else
    res="$R7"
fi
echo "\t$R7"

if [ "$res" = "--" ]; then
  R=`timeout 100 "$DUET"/patools.native match-embeds $file`
  if ! [ "$R" = "" ]; then
    res="$R"
  fi
fi

echo "$res"
