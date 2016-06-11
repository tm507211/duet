Ark
====
This branch is a stripped-down version of the Duet's Ark library.

Building
========

### Dependencies

Ark depends on several software packages.  The following dependencies need to be installed manually.

 + [opam](http://opam.ocaml.org) (with OCaml >= 4.02 & native compiler)
 + GMP and MPFR

On Ubuntu, you can install these packages (except Java) with:
```
 sudo apt-get install opam libgmp-dev libmpfr-dev
```

Next, add the [sv-opam](https://github.com/zkincaid/sv-opam) OPAM repository, and install the rest of duet's dependencies.  These are built from source, so grab a coffee &mdash; this may take a long time.
```
 opam remote add sv git://github.com/zkincaid/sv-opam.git
 opam install ocamlgraph batteries cil oasis ppx_deriving camlidl mlgmpidl Z3 ounit
```

### Building Ark

After Ark's dependencies are installed, it can be built with `make ark`.

Running Ark
===========

Ark accepts input in SMTLIB2 format.

- `./arkTop.native sat <FILE>`: test LIRA satisfiability using the SIMSAT algorithm (IJCAI'16)
- `./arkTop.native sat-forward <FILE>`: test LIRA satisfiability using the forward variant of the SIMSAT algorithm (IJCAI'16)
- `./arkTop.native sat-z3qe <FILE>`: test LIRA satisfiability using the Z3's built-in quantifier elimination
- `./arkTop.native sat-mbp <FILE>`: test LRA satisfiability using model-based projection
- `./arkTop.native mbp <FILE>`: LRA quantifier elimination via model-based projection
