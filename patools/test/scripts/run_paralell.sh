#!/usr/bin/make -f

THIS := $(lastword $(MAKEFILE_LIST))
TARGETS := match-embeds crypto-mini-sat haifacsp ortools vf2 lingeling gecode

.PHONY: all $(TARGETS)

all: $(TARGETS)

$(TARGETS):
	-touch $@/hard3.out && cd $@ && ../run_solver.sh ../../hard3 $@ $(shell cat $@/hard3.out | wc -l) >> hard3.out

THIS := $(lastword $(MAKEFILE_LIST))
