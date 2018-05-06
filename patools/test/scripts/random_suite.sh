#!/bin/bash
NB=0
TO=1
DIR="../embed_bench"
if ! [ -z $1 ]; then
    DIR="$1"
fi

while [[ $NB -lt 100 ]]; do
    predicates=$((2 + RANDOM % 9)) # ~[2,10]
    size1=$((10 + RANDOM % 41))    # ~[10,50]
    size2=$(($size1 + RANDOM % ($size1 + 1))) # ~[size1,2*size1]
    ppred1=`printf "%02d\n" $((1 + RANDOM % 25))` # ~(0,0.25)
    ppred2=`printf "%02d\n" $((2*10#$ppred1 + RANDOM % (2*10#$ppred1)))` # ~[2*ppred1,4*ppred1)
    pedge1=`printf "%02d\n" $((1 + RANDOM % 10))` # ~(0,0.1)
    pedge2=`printf "%02d\n" $((10#$pedge1 + RANDOM % (4*10#$ppred1)))` # ~[4*pedge1,8*pedge1)
    python random_struct.py $size1 $predicates 0.$ppred1 0.$pedge1 > embed.struct
    python random_struct.py $size2 $predicates 0.$ppred2 0.$pedge2 >> embed.struct
    R1=`timeout $TO ../../../patools.native match-embeds embed.struct`
    R2=`timeout $TO ../../../patools.native haifacsp embed.struct`
    R3=`timeout $TO ../../../patools.native crypto-mini-sat embed.struct`
    R4=`timeout $TO ../../../patools.native gecode embed.struct`
    R5=`timeout $TO ../../../patools.native vf2 embed.struct`
    if [[ "$R1" = "" || "$R2" = "" || "$R3" = "" || "$R4" = "" || "$R5" = "" ]]; then
	bench=`printf "$DIR/embed%03d.struct" $NB`
	cp embed.struct $bench
	if [ "$R1" = "" ]; then
	    echo "MatchEmbeds timeout ($R2,$R3,$R4,$R5)"
	elif [ "$R2" = "" ]; then
	    echo "haifa_csp timeout ($R1,$R3,$R4,$R5)"
	elif [ "$R3" = "" ]; then
	    echo "CryptoMiniSAT timeout ($R1,$R2,$R4,$R5)"
	elif [ "$R4" = "" ]; then
	    echo "Gecode timeout ($R1,$R2,$R3,$R5)"
	else
	    echo "VF2 timeout ($R1,$R2,$R3,$R5)"
	fi
	NB=$(($NB + 1))
    else
	echo "Success: $R1"
    fi
done
