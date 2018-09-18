open Syntax
open Smt

(** Satisfiability via strategy improvement *)
val simsat : 'a context -> 'a formula -> [ `Sat | `Unsat | `Unknown ]

(** Satisfiability via strategy improvement, forwards version *)
val simsat_forward : 'a context -> 'a formula -> [ `Sat
                                                 | `Unsat
                                                 | `Unknown ]

(** Alternating quantifier optimization *)
val maximize : 'a context -> 'a formula -> 'a term -> [ `Bounded of QQ.t
                                                      | `Infinity
                                                      | `MinusInfinity
                                                      | `Unknown ]

(** Quantifier eliminiation via model-based projection *)
val qe_mbp : 'a context -> 'a formula -> 'a formula

(** Model-based projection.  If [dnf] option is set, convert to
   disjunctive normal form. *)
val mbp : ?dnf:bool -> 'a context -> (symbol -> bool) -> 'a formula -> 'a formula

(** Alternating quantifier satisfiability *)
val easy_sat : 'a context -> 'a formula -> [ `Sat | `Unsat | `Unknown ]

type 'a strategy

type quantifier_prefix = ([`Forall | `Exists] * symbol) list

val pp_strategy : 'a context -> Format.formatter -> 'a strategy -> unit

val show_strategy : 'a context -> 'a strategy -> string


(** Compute a winning SAT/UNSAT strategy for a formula.  The formula is
    represented in prenex form (quantifier prefix + matrix). *)
val winning_strategy : 'a context -> quantifier_prefix -> 'a formula ->
  [ `Sat of 'a strategy
  | `Unsat of 'a strategy
  | `Unknown ]

(** Verify that a SAT strategy is in fact a winning strategy.  (To verify an
    UNSAT strategy, just negate the formula & quantifier prefix) *)
val check_strategy : 'a context -> quantifier_prefix -> 'a formula ->
  'a strategy -> bool

(** Write a formula in prenex normal form, using constant symbols instead of
    variables. *)
val normalize : 'a context -> 'a formula -> quantifier_prefix * 'a formula

val is_presburger_atom : 'a context -> 'a formula -> bool
