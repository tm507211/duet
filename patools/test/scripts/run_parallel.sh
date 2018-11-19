#!/usr/bin/make -f

THIS := $(lastword $(MAKEFILE_LIST))
SOLVERS := gecode #match-embeds crypto-mini-sat haifacsp ortools vf2 lingeling
INPUTS := ../../hard_monadic2 ../../hard_ternary2 #../../hard_binary ../../hard_ternary

TARGETS := $(foreach X,$(INPUTS), $(foreach Y,$(SOLVERS), $X\:$Y))

.PHONY: all $(TARGETS)

all: $(TARGETS)

$(TARGETS):
	$(eval INPUT := $(word 1,$(subst :, ,$@)))
	$(eval SOLVER := $(word 2, $(subst :, ,$@)))
	$(eval OUTPUT := $(notdir $(INPUT)))
	touch $(SOLVER)/$(OUTPUT)
	-cd $(SOLVER) && ../run_solver.sh $(INPUT) $(SOLVER) $(shell cat $(SOLVER)/$(OUTPUT) | wc -l) >> $(OUTPUT)

THIS := $(lastword $(MAKEFILE_LIST))
