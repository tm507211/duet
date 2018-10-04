#!/bin/bash

R=$(minizinc --solver org.ortools.ortools "tmp.mzn" 2> /dev/null)

if echo "$R" | grep --quiet "UNSAT"; then
    exit 1
elif echo "$R" | grep --quiet -e "----------"; then
    exit 0
else
    exit 2
fi
