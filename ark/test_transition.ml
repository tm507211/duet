open Apak
open OUnit
open ArkPervasives

module StrVar = struct
  include Putil.PString
  let prime x = x ^ "'"
  let to_smt x = 
    if String.get x 0 == 'r' then Smt.real_var x
    else Smt.int_var x
  let of_smt sym = match Smt.symbol_refine sym with
    | Smt.Symbol_string str -> str
    | Smt.Symbol_int _ -> assert false
  let typ x =
    if String.get x 0 == 'r' then TyReal
    else TyInt
  module E = Enumeration.Make(Putil.PString)
  let enum = E.empty ()
  let tag = E.to_int enum
end

module K = Transition.Make(StrVar)

module V = struct
  type t = int deriving (Compare)
  let equal = (=)
  let compare = Pervasives.compare
  let hash x = x
end

type cmd =
  | Assign of StrVar.t * K.T.t
  | Assume of K.F.t
        deriving (Show,Compare)
module CmdSyntax = struct
  let ( := ) x y = Assign (x, y)
  let ( ?! ) x = Assume x
  include K.T.Syntax
  include K.F.Syntax
end

module E = struct
  type t = cmd deriving (Show,Compare)
  let default = Assume K.F.top
  let compare = Compare_t.compare
end
module G = Graph.Persistent.Digraph.ConcreteLabeled(V)(E)
module A = Pathexp.MakeElim(G)(K)

let mk_tmp () = K.T.var (K.V.mk_tmp "nondet" TyReal)
let var v = K.T.var (K.V.mk_var v)
let const k = K.T.int (ZZ.of_int k)

let weight e =
  let open K in
  match G.E.label e with
  | Assign (v, t) -> K.assign v t
  | Assume phi -> K.assume phi

let run_test graph src tgt =
  let res = A.path_expr graph weight src tgt in
  let s = new Smt.solver in
  fun phi expected -> begin
      s#push ();
      let mk () = K.V.mk_tmp "nonlin" TyReal in
      Log.logf "Nonlin path condition:@\n%a" K.F.format
        (K.F.conj (K.to_formula res) (K.F.negate phi));
      let path_condition =
        K.F.linearize mk (K.F.conj (K.to_formula res) (K.F.negate phi))
      in
      Log.logf "Path condition:@\n%a" K.F.format path_condition;
      s#assrt (K.F.to_smt path_condition);
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    end

let mk_graph edges =
  let add_edge g (src, label, tgt) =
    G.add_edge_e g (G.E.create src label tgt)
  in
  List.fold_left add_edge G.empty edges

let counter =
  let edges =
    [(0, Assume (K.F.gt (var "n") (const 0)), 1);       (* [n > 0] *)
     (1, Assign ("i", const 0), 2);                     (* i := 0 *)
     (2, Assume (K.F.lt (var "i") (var "n")), 3);       (* [i < n] *)
     (3, Assign ("i", K.T.add (var "i") (const 1)), 2); (* i := i + 1 *)
     (2, Assume (K.F.geq (var "i") (var "n")), 4)]      (* [i >= n] *)
  in
  mk_graph edges

let test_counter () =
  let phi = K.F.eq (var "i'") (var "n") in
  run_test counter 0 4 phi Smt.Unsat

let set_opt_simple () =
  let open K in
  opt_higher_recurrence := true;
  opt_disjunctive_recurrence_eq := true;
  opt_recurrence_ineq := false;
  opt_higher_recurrence_ineq := false;
  opt_unroll_loop := true;
  opt_loop_guard := None;
  opt_polyrec := false

let set_opt_const_bound () =
  let open K in
  opt_higher_recurrence := true;
  opt_disjunctive_recurrence_eq := false;
  opt_recurrence_ineq := true;
  opt_higher_recurrence_ineq := false;
  opt_unroll_loop := false;
  opt_loop_guard := Some F.exists;
  opt_polyrec := false

let set_opt_sym_bound () =
  let open K in
  opt_higher_recurrence := true;
  opt_disjunctive_recurrence_eq := false;
  opt_higher_recurrence_ineq := true;
  opt_recurrence_ineq := false;
  opt_unroll_loop := true;
  opt_loop_guard := None;
  opt_polyrec := false

let set_opt_polyrec () =
  let open K in
  opt_higher_recurrence := true;
  opt_disjunctive_recurrence_eq := false;
  opt_higher_recurrence_ineq := false;
  opt_recurrence_ineq := false;
  opt_unroll_loop := false;
  opt_loop_guard := Some F.exists;
  opt_polyrec := true


(* from sv-comp13/loops/count_up_down_safe *)
let count_up_down_safe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let x = var "x" in
  let y = var "y" in
  let n = var "n" in
  let edges =
    [(0, (?! (n >= (~@ 0))), 1); (* nondet uint *)
     (1, ("x" := n), 2);
     (2, ("y" := (~@ 0)), 3);
     (3, (?! (x > (~@ 0))), 4);
     (4, ("x" := x - (~@ 1)), 5);
     (5, ("y" := y + (~@ 1)), 3);
     (3, (?! (x <= (~@ 0))), 6)]
  in
  mk_graph edges
let test_count_up_down_safe () =
  let phi = K.F.eq (var "y'") (var "n") in
  set_opt_simple ();
  run_test count_up_down_safe 0 6 phi Smt.Unsat

(* from sv-comp13/loops/sum01_safe *)
let sum01_safe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let a = ~@ 2 in
  let sn = var "sn" in
  let n = var "n" in
  let i = var "i" in
  let edges =
    [(0, ("i" := (~@ 1)), 1);
     (1, ("sn" := (~@ 0)), 2);
     (2, (?! (i <= n)), 3);
     (3, ("sn" := (sn + a)), 4);
     (4, ("i" := (i + (~@ 1))), 2);
     (2, (?! (i > n)), 5)]
  in
  mk_graph edges
let test_sum01_safe () =
  let open CmdSyntax in
  let phi =
    (var "sn'") == ((var "n") * (~@ (QQ.of_int 2)))
    || (var "sn'") == (~@ QQ.zero)
  in
  set_opt_simple ();
  run_test sum01_safe 0 5 phi Smt.Unsat

(* from sv-comp13/loops/sum01_unsafe *)
let sum01_unsafe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let a = ~@ 2 in
  let sn = var "sn" in
  let n = var "n" in
  let i = var "i" in
  let edges =
    [(0, ("i" := (~@ 1)), 1);
     (1, ("sn" := (~@ 0)), 2);
     (2, (?! (i <= n)), 3);

     (3, (?! (i < (~@ 10))), 10);
     (10, ("sn" := (sn + a)), 4);

     (3, (?! (i >= (~@ 10))), 4);

     (4, ("i" := (i + (~@ 1))), 2);
     (2, (?! (i > n)), 5)]
  in
  mk_graph edges
let test_sum01_unsafe () =
  let open CmdSyntax in
  let phi =
    (var "sn'") == ((var "n") * (~@ (QQ.of_int 2)))
    || (var "sn'") == (~@ QQ.zero)
  in
  set_opt_simple ();
  run_test sum01_unsafe 0 5 phi Smt.Sat

(* from sv-comp13/loops/sum02_safe *)
let sum02_safe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let sn = var "sn" in
  let n = var "n" in
  let i = var "i" in
  let edges =
    [(0, ("i" := (~@ 0)),1);
     (1, ("sn" := (~@ 0)), 2);
     (2, (?! (i <= n)), 3);
     (3, ("sn" := (sn + i)), 4);
     (4, ("i" := (i + (~@ 1))), 2);
     (2, (?! (i > n)), 5)]
  in
  mk_graph edges
let test_sum02_safe () =
  let open CmdSyntax in
  let sn = var "sn'" in
  let n = var "n" in
  let i = var "i'" in

  let phi =
    (sn == (((n * n) / (~@ (QQ.of_int 2))) + (n / (~@ (QQ.of_int 2)))))
    || i == (~@ QQ.zero)
  in
  set_opt_simple ();
  run_test sum02_safe 0 5 phi Smt.Unsat


(* from sv-comp13/loops/sum03_safe *)
let sum03_safe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let sn = var "sn" in
  let a = ~@ 2 in
  let x = var "x" in
  let edges =
    [(0, ("sn" := (~@ 0)), 1);
     (1, ("x" := (~@ 0)), 2);
     (2, ("sn" := sn + a), 3);
     (3, ("x" := x + (~@ 1)), 4);
     (4, (?! (a == a)), 2)]
  in
  mk_graph edges
let test_sum03_safe () =
  let open CmdSyntax in
  let phi =
    (var "sn'") == ((var "x'") * (~@ (QQ.of_int 2)))
    (* this disjunt appears in sum03_safe, but isn't needed *)
    (*    || (~$ "sn'") == (~@ 0)*)
  in
  set_opt_simple ();
  run_test sum03_safe 0 4 phi Smt.Unsat

(* from sv-comp13/loops/sum03_unsafe *)
let sum03_unsafe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let sn = var "sn" in
  let a = ~@ 2 in
  let x = var "x" in
  let edges =
    [(0, ("sn" := (~@ 0)), 1);
     (1, ("x" := (~@ 0)), 2);

     (2, (?! (x < (~@ 10))), 3);
     (3, ("sn" := sn + a), 4);

     (2, (?! (x >= (~@ 10))), 4);

     (4, ("x" := x + (~@ 1)), 5);
     (5, (?! (a == a)), 2)]
  in
  mk_graph edges
let test_sum03_unsafe () =
  let open CmdSyntax in
  let phi =
    (var "sn'") == ((var "x'") * (~@ (QQ.of_int 2)))
    || (var "sn'") == (~@ QQ.zero)
  in
  set_opt_simple ();
  run_test sum03_unsafe 0 5 phi Smt.Sat

let third_order_safe =
  let open CmdSyntax in
  let (~@) x = ~@ (QQ.of_int x) in
  let sn = var "sn" in
  let ssn = var "ssn" in
  let n = var "n" in
  let i = var "i" in
  let edges =
    [(0, ("i" := (~@ 0)), 1);
     (1, ("sn" := (~@ 0)), 2);
     (2, ("ssn" := (~@ 0)), 3);
     (3, (?! (i < n)), 4);
     (4, ("i" := (i + (~@ 1))), 5);
     (5, ("sn" := (sn + i)), 6);
     (6, ("ssn" := (ssn + sn)), 3);
     (3, (?! (i >= n)), 7)]
  in
  mk_graph edges
let test_third_order_safe () =
  let open CmdSyntax in
  let n = var "n" in
  let phi0 =
    (var "i'" == var "n")
    || (var "i'") == (~@ QQ.zero)
  in
  let phi1 =
    ((var "sn'") == (((n * n) / (~@ (QQ.of_int 2))) + (n / (~@ (QQ.of_int 2)))))
    || (var "sn'") == (~@ QQ.zero)
  in
  let phi2 =
    (var "ssn'") ==
    ((var "n")*((var "n")*(var "n"))) / (~@ (QQ.of_int 6))
    + ((var "n")*(var "n")) / (~@ (QQ.of_int 2))
    + ((var "n") / (~@ (QQ.of_int 3)))
    || (var "ssn'") == (~@ QQ.zero)
  in
  set_opt_polyrec ();
  run_test third_order_safe 0 7 phi0 Smt.Unsat;
  run_test third_order_safe 0 7 phi1 Smt.Unsat;
  run_test third_order_safe 0 7 phi2 Smt.Unsat


let test_widen () =
  let open CmdSyntax in
  let x = var "x" in
  let tr =
    K.mul
      (K.assume (x >= (~@ (QQ.of_int 0))))
      (K.assign "x" (x + (~@ (QQ.of_int 1))))
  in
  let tr2 = K.mul tr tr in
  let w = K.widen tr tr2 in
  let v = K.T.var (K.V.mk_tmp "havoc" TyInt) in
  let expected =
    { K.transform = K.M.add "x" v K.M.empty;
      K.guard = (x >= (~@ QQ.zero)) }
  in
  assert_equal ~cmp:K.equal ~printer:K.show expected w

module SymBound = struct
  module T = K.T
  module F = K.F

  let frac x y = K.T.const (QQ.of_frac x y)
  let var x = K.T.var (K.V.mk_var x)
  let block = BatList.reduce K.mul
  let while_loop cond body =
    K.mul (K.star (block ((K.assume cond)::body))) (K.assume (F.negate cond))

  let test_const_bounds () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_sym_bound ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rtmp = var "rtmp" in
    let prog =
      block [
        K.assign "rx" (~@ 0);
        K.assign "ry" (~@ 0);
        while_loop (rx < (~@ 10)) [
          K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
          K.assume (ry - (frac 1 3) <= rtmp && rtmp < ry + (frac 1 7));
          K.assign "ry" rtmp;
          K.assign "rx" (rx + (~@ 1))
        ]
      ]
    in
    let s = new Smt.solver in
    s#assrt (K.to_smt prog);
    Log.logf "Formula: %a" K.format prog;
    let check phi expected =
      s#push ();
      s#assrt (Smt.mk_not (F.to_smt phi));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "rx'" == (~@ 10)) Smt.Unsat;
    check (var "ry'" < (frac 10 7)) Smt.Unsat;
    check (var "ry'" >= T.neg (frac 10 3)) Smt.Unsat

  let test_symbolic_bounds () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_sym_bound ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let rt = var "rt" in
    let reps = var "reps" in
    let rtmp = var "rtmp" in
    let mu = T.const (QQ.exp (QQ.of_int 2) (-53)) in
    let decr = (~@ 1) / (~@ 10) in
    let prog =
      block [
        K.assume ((~@ 0) <= rx && rx <= (~@ 1000));
        K.assign "reps" (~@ 0);
        while_loop ((rx > (~@ 0)) && (rx + reps > (~@ 0))) [
          K.assume (reps <= (~@ 1) && reps >= (~@ -1));
          K.assign "rt" (rx + reps - decr + (decr * mu));
          K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
          K.assume ((rt - (rt * mu) - rx + decr <= rtmp)
                    && (rtmp <= rt + (rt * mu) - rx + decr));
          K.assign "reps" rtmp;
          K.assign "rx" (rx - decr)
        ]
      ]
    in
    let s = new Smt.solver in
    Log.logf "Formula: %a" K.format prog;
    let mk () = K.V.mk_tmp "nonlin" TyReal in
    let check phi expected =
      s#push ();
      s#assrt (K.F.to_smt (K.F.linearize mk (K.to_formula prog
                                             && K.F.negate phi)));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check ((var "rx'") > T.neg (frac 1 10)) Smt.Unsat;
    check ((var "reps'") <= (frac 1 100000000)) Smt.Unsat;
    check ((var "reps'") >= (frac (-1) 100000000)) Smt.Unsat
end

module Bound = struct
  (*  module K = Transition.MakeBound(StrVar)*)
  (*  module A = Pathexp.MakeElim(G)(K)*)
  module T = K.T
  module F = K.F
  let frac x y = K.T.const (QQ.of_frac x y)
  let var x = K.T.var (K.V.mk_var x)
  let block = BatList.reduce K.mul
  let while_loop cond body =
    K.mul (K.star (block ((K.assume cond)::body))) (K.assume (F.negate cond))

  let test_const_bounds () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_const_bound ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rtmp = var "rtmp" in
    let prog =
      block [
        K.assign "rx" (~@ 0);
        K.assign "ry" (~@ 0);
        while_loop (rx < (~@ 10)) [
          K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
          K.assume (ry - (frac 1 3) <= rtmp && rtmp < ry + (frac 1 7));
          K.assign "ry" rtmp;
          K.assign "rx" (rx + (~@ 1))
        ]
      ]
    in
    let s = new Smt.solver in
    s#assrt (K.to_smt prog);
    Log.logf "Formula: %a" K.format prog;
    Log.logf "Smt: %s" (Smt.ast_to_string (K.to_smt prog));
    let check phi expected =
      s#push ();
      s#assrt (Smt.mk_not (F.to_smt phi));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "rx'" == (~@ 10)) Smt.Unsat;

    (* Bounds detection doesn't currently handle strict inequalities *)
    check (var "ry'" <= (frac 10 7)) Smt.Unsat;
    check (var "ry'" > T.neg (frac 10 3)) Smt.Sat;
    check (var "ry'" >= T.neg (frac 10 3)) Smt.Unsat

  let test_nested () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_const_bound ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rz = var "rz" in
    let rtmp = var "rtmp" in
    let prog =
      block [
        K.assign "rx" (~@ 0);
        K.assign "ry" (~@ 0);
        while_loop (rx < (~@ 2)) [
          K.assign "rz" (~@ 0);
          while_loop (rz < (~@ 5)) [
            K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
            K.assume (ry - (frac 1 3) <= rtmp && rtmp <= ry + (frac 1 7));
            K.assign "ry" rtmp;
            K.assign "rz" (rz + (~@ 1));
          ];
          K.assign "rx" (rx + (~@ 1))
        ]
      ]
    in
    let s = new Smt.solver in
    s#assrt (K.to_smt prog);
    Log.logf "Formula: %a" K.format prog;
    let check phi expected =
      s#push ();
      s#assrt (Smt.mk_not (F.to_smt phi));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "ry'" <= (frac 10 7)) Smt.Unsat;
    check (var "ry'" >= T.neg (frac 10 3)) Smt.Unsat;
    check (var "ry'" < (frac 10 7)) Smt.Sat;
    check (var "ry'" > T.neg (frac 10 3)) Smt.Sat

  let test_nested_unbounded () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_const_bound ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rz = var "rz" in
    let prog =
      block [
        K.assign "rz" (~@ 0);
        K.assume (rx > (~@ 0));
        while_loop (rx >= (~@ 0)) [
          K.assign "ry" (~@ 0);
          while_loop (ry < (~@ 1)) [
            K.assign "ry" (ry + (frac 1 10));
            K.assign "rz" (rz + (frac 1 2))
          ];
          while_loop (ry > (~@ 0)) [
            K.assign "ry" (ry - (frac 1 10));
            K.assign "rz" (rz - (frac 1 2))
          ];
          K.assign "rx" (rx - (~@ 1));
        ]
      ]
    in
    let s = new Smt.solver in
    s#assrt (K.to_smt prog);
    Log.logf "Formula: %a" K.format prog;
    let check phi expected =
      s#push ();
      s#assrt (Smt.mk_not (F.to_smt phi));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "ry'" == (frac 0 1)) Smt.Unsat;
    check (var "rz'" >= (T.neg (frac 1 2))) Smt.Unsat;
    check (var "rz'" <= (~@ 0)) Smt.Unsat;
    check F.bottom Smt.Sat
end


module Polyrec = struct
  module T = K.T
  module F = K.F
  let frac x y = K.T.const (QQ.of_frac x y)
  let var x = K.T.var (K.V.mk_var x)
  let block = BatList.reduce K.mul
  let while_loop cond body =
    K.mul (K.star (block ((K.assume cond)::body))) (K.assume (F.negate cond))


  let test_const_bounds () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_polyrec ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rtmp = var "rtmp" in
    let prog =
      block [
        K.assign "rx" (~@ 0);
        K.assign "ry" (~@ 0);
        while_loop (rx < (~@ 10)) [
          K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
          K.assume (ry - (frac 1 3) <= rtmp && rtmp < ry + (frac 1 7));
          K.assign "ry" rtmp;
          K.assign "rx" (rx + (~@ 1))
        ]
      ]
    in
    let s = new Smt.solver in
    let check phi expected =
      s#push ();
      let mk () = K.V.mk_tmp "nonlin" TyReal in
      let path_condition =
        K.F.linearize mk (K.F.conj (K.to_formula prog) (K.F.negate phi))
      in
      s#assrt (F.to_smt path_condition);
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "rx'" == (~@ 10)) Smt.Unsat;
    check (var "ry'" < (frac 10 7)) Smt.Unsat;
    check (var "ry'" >= T.neg (frac 10 3)) Smt.Unsat

  let test_nested () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_polyrec ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rz = var "rz" in
    let rtmp = var "rtmp" in
    let prog =
      block [
        K.assign "rx" (~@ 0);
        K.assign "ry" (~@ 0);
        while_loop (rx < (~@ 2)) [
          K.assign "rz" (~@ 0);
          while_loop (rz < (~@ 5)) [
            K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
            K.assume (ry - (frac 1 3) <= rtmp && rtmp <= ry + (frac 1 7));
            K.assign "ry" rtmp;
            K.assign "rz" (rz + (~@ 1));
          ];
          K.assign "rx" (rx + (~@ 1))
        ]
      ]
    in
    let s = new Smt.solver in
    Log.logf "Formula: %a" K.format prog;
    let check phi expected =
      s#push ();
      let mk () = K.V.mk_tmp "nonlin" TyReal in
      let path_condition =
        K.F.linearize mk (K.F.conj (K.to_formula prog) (K.F.negate phi))
      in
      s#assrt (F.to_smt path_condition);
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "ry'" <= (frac 10 7)) Smt.Unsat;
    check (var "ry'" >= T.neg (frac 10 3)) Smt.Unsat;
    check (var "ry'" < (frac 10 7)) Smt.Sat;
    check (var "ry'" > T.neg (frac 10 3)) Smt.Sat

  (* k/3 <= (ry' - ry) <= k/7 *)
  (* 7ry' - 7ry - k <= 0 *)

  let test_nested_unbounded () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_polyrec ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let ry = var "ry" in
    let rz = var "rz" in
    let prog =
      block [
        K.assign "rz" (~@ 0);
        K.assume (rx > (~@ 0));
        while_loop (rx >= (~@ 0)) [
          K.assign "ry" (~@ 0);
          while_loop (ry < (~@ 1)) [
            K.assign "ry" (ry + (frac 1 10));
            K.assign "rz" (rz + (frac 1 2))
          ];
          while_loop (ry > (~@ 0)) [
            K.assign "ry" (ry - (frac 1 10));
            K.assign "rz" (rz - (frac 1 2))
          ];
          K.assign "rx" (rx - (~@ 1));
        ]
      ]
    in
    let s = new Smt.solver in
    let check phi expected =
      s#push ();
      let mk () = K.V.mk_tmp "nonlin" TyReal in
      let path_condition =
        K.F.linearize mk (K.F.conj (K.to_formula prog) (K.F.negate phi))
      in
      s#assrt (F.to_smt path_condition);
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check (var "ry'" == (frac 0 1)) Smt.Unsat;
    check (var "rz'" >= (T.neg (frac 1 2))) Smt.Unsat;
    check (var "rz'" <= (~@ 0)) Smt.Unsat;
    check F.bottom Smt.Sat

  let test_symbolic_bounds () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_polyrec ();
    let (~@) x = ~@ (QQ.of_int x) in
    let rx = var "rx" in
    let rt = var "rt" in
    let reps = var "reps" in
    let rtmp = var "rtmp" in
    let mu = T.const (QQ.exp (QQ.of_int 2) (-53)) in
    let decr = (~@ 1) / (~@ 10) in
    let prog =
      block [
        K.assume ((~@ 0) <= rx && rx <= (~@ 1000));
        K.assign "reps" (~@ 0);
        while_loop ((rx > (~@ 0)) && (rx + reps > (~@ 0))) [
          K.assume (reps <= (~@ 1) && reps >= (~@ -1));
          K.assign "rt" (rx + reps - decr + (decr * mu));
          K.assign "rtmp" (K.T.var (K.V.mk_tmp "havoc" TyReal));
          K.assume ((rt - (rt * mu) - rx + decr <= rtmp)
                    && (rtmp <= rt + (rt * mu) - rx + decr));
          K.assign "reps" rtmp;
          K.assign "rx" (rx - decr)
        ]
      ]
    in
    let s = new Smt.solver in
    Log.logf "Formula: %a" K.format prog;
    let mk () = K.V.mk_tmp "nonlin" TyReal in
    let check phi expected =
      s#push ();
      s#assrt (K.F.to_smt (K.F.linearize mk (K.to_formula prog
                                             && K.F.negate phi)));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check ((var "rx'") > T.neg (frac 1 10)) Smt.Unsat;
    check ((var "reps'") <= (frac 1 100000000)) Smt.Unsat;
    check ((var "reps'") >= (frac (-1) 100000000)) Smt.Unsat

  let test_mult () =
    let open K.T.Syntax in
    let open K.F.Syntax in
    set_opt_polyrec ();
    let (~@) x = ~@ (QQ.of_int x) in
    let x = var "x" in
    let y = var "y" in
    let z = var "z" in
    let i = var "i" in
    let prog =
      block [
        K.assume (x >= (~@ 0));
        K.assign "i" (~@ 0);
        K.assign "z" (~@ 0);
        while_loop (i < x) [
          K.assign "i" (i + (~@ 1));
          K.assign "z" (z + y);
        ];
      ]
    in
    let s = new Smt.solver in
    Log.logf "Formula: %a" K.format prog;
    let mk () = K.V.mk_tmp "nonlin" TyReal in
    let check phi expected =
      s#push ();
      s#assrt (K.F.to_smt (K.F.linearize mk (K.to_formula prog
                                             && K.F.negate phi)));
      assert_equal ~printer:Show.show<Smt.lbool> expected (s#check());
      s#pop ();
    in
    check ((var "i'") == x) Smt.Unsat;
    check ((var "z'") == x * y) Smt.Unsat
end


let suite = "Transition" >:::
            [
              "counter" >:: test_counter;
              "count_up_down_safe" >:: test_count_up_down_safe;
              "sum01_safe" >:: test_sum01_safe;
              "sum01_unsafe" >:: test_sum01_unsafe;
              "sum02_safe" >:: test_sum02_safe;
              "sum03_safe" >:: test_sum03_safe;
              "sum03_unsafe" >:: test_sum03_unsafe;
              "third_order_safe" >:: test_third_order_safe;
              "widen" >:: test_widen;

              "symbound_const" >:: SymBound.test_const_bounds;
              "symbound_symbolic" >:: SymBound.test_symbolic_bounds;
              "bound_const" >:: Bound.test_const_bounds;
              "nested" >:: Bound.test_nested;
              "nested_unbounded" >:: Bound.test_nested_unbounded;

              "polyrec_bound_const" >:: Polyrec.test_const_bounds;
              "polyrec_nested" >:: Polyrec.test_nested;
              "polyrec_nested_unbounded" >:: Polyrec.test_nested_unbounded;
              "polyrec_symbolic" >:: Polyrec.test_symbolic_bounds;
              "polyrec_mult" >:: Polyrec.test_mult;
            ]
