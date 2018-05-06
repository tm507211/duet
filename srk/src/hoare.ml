open Syntax
open Transition
open SrkZ3
open BatPervasives

include Log.Make(struct let name = "srk.hoare" end)

module type Letter = sig
  type t
  type trans
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val pp : Format.formatter -> t -> unit

  val transition_of : t -> trans
end

module MakeSolver(Ctx : Syntax.Context) (Var : Transition.Var) (Ltr : Letter with type trans = Transition.Make(Ctx)(Var).t) = struct

  module Infix = Syntax.Infix(Ctx)
  module Transition = Transition.Make(Ctx)(Var)

  type transition = Ltr.trans
  type formula = Ctx.formula
  type triple = (formula list) * Ltr.t * (formula list)

  module DA = BatDynArray

  let srk = Ctx.context

  let pp_triple formatter (pre, ltr, post) =
    let open Format in
    fprintf formatter "{";
    SrkUtil.pp_print_enum ~pp_sep:(fun formatter () -> fprintf formatter " /\\ ")
                          (Expr.pp srk)
                          formatter
                          (BatList.enum pre);
    fprintf formatter "} ";
    Ltr.pp formatter ltr;
    fprintf formatter " {";
    SrkUtil.pp_print_enum ~pp_sep:(fun formatter () -> fprintf formatter " /\\ ")
                          (Expr.pp srk)
                          formatter
                          (BatList.enum post);
    fprintf formatter "}"

  type t = {
      smt_ctx : Ctx.t z3_context;
      solver : Ctx.t CHC.solver;
      triples : triple DA.t;
    }

  let mk_solver () =
    let smt_ctx = mk_context srk [] in
    { smt_ctx = smt_ctx;
      solver = CHC.mk_solver smt_ctx;
      triples = DA.create();
    }

  let get_solver solver =
    solver.solver

  (*
     register {[P(...) ; Q(...); x = 3; y < x]} transition {[R(...); S(...)]}
     as P(...) /\ Q(...) /\ x = 3 /\ y < x /\ transition.guard --> R(...)
        P(...) /\ Q(...) /\ x = 3 /\ y < x /\ transition.guard --> S(...)
   *)
  let register_triple solver (pre, ltr, post) =
    (* logf ~level:`always "%a" pp_triple (pre, ltr, post); *)
    let rec register_formulas formulas =
      match formulas with
      | [] -> ()
      | form :: forms ->
         begin
           match destruct srk form with
           | `App (p, _) -> CHC.register_relation solver.solver p
           | _ -> ()
         end; register_formulas forms
    in
    let fresh =
      let ind : int ref = ref (-1) in
      Memo.memo (fun sym ->
          match typ_symbol srk sym with
          | `TyInt  -> incr ind; mk_var srk (!ind) `TyInt
          | `TyReal -> incr ind; mk_var srk (!ind) `TyReal
          | `TyBool -> incr ind; mk_var srk (!ind) `TyBool
          | _ -> mk_const srk sym
        )
    in
    let trans = Ltr.transition_of ltr in
    let body = (* conjunct all preconditions and guard of the transition *)
      let rec go rels =
        match rels with
        | [] -> substitute_const srk fresh (Transition.guard trans)
        | rel :: rels -> mk_and srk [(substitute_const srk fresh rel); go rels]
      in go pre
    in
    let add_rules posts =
      let postify sym = 
        match Var.of_symbol sym with
        | Some v when Transition.mem_transform v trans ->
             substitute_const srk fresh (Transition.get_transform v trans)
        | _ -> fresh sym
      in
      let rec go posts = (* add a rule for each post condition *)
        match posts with
        | [] -> ()
        | post :: posts -> CHC.add_rule solver.solver body (substitute_const srk postify post); go posts
      in
      go posts
    in
    DA.add solver.triples (pre, ltr, post);
    register_formulas pre;
    register_formulas post;
    add_rules post

  let check_solution solver = CHC.check solver.solver []

  let get_solution solver =
    let get_triple trips (pre, ltr, post) =
      let rec subst =
        let rewriter expr =
          match destruct srk expr with
          | `App (_, []) -> expr
          | `App (rel, args) ->
             (substitute srk
                (fun (v, _) -> List.nth args v)
                (CHC.get_solution solver.solver rel) :> ('a, typ_fo) Syntax.expr)
          | _ -> expr
        in
        function
        | [] -> []
        | rel :: rels ->
           (rewrite srk ~down:rewriter rel) :: (subst rels)
      in
      (subst pre, ltr, subst post) :: trips
    in
    List.rev (DA.fold_left get_triple [] solver.triples)

  let get_symbolic solver =
    DA.to_list solver.triples

  let verify_solution solver =
    match CHC.check solver.solver [] with
    | `Sat ->
       List.fold_left (fun ret (pre, ltr, post) ->
           match ret with
           | `Invalid -> `Invalid
           | x ->
              match (Transition.valid_triple (Ctx.mk_and pre) [Ltr.transition_of ltr] (Ctx.mk_and post)) with
              | `Valid -> x
              | y -> y
         ) `Valid (get_solution solver)
    | `Unsat -> `Invalid
    | `Unknown -> `Unknown

  (* takes a triple and creates a new hoare triple for each conjunct of the post post.
     Then removes irrelevant pre conditions using unsat core *)
  let simplify (pre, letter, post) =
    let rec conjuncts phi =
      match Syntax.destruct srk phi with
      | `Tru -> []
      | `And conjs -> List.flatten (List.map conjuncts conjs)
      | _ -> [phi]
    in
    let mk_and conjs =
      match conjs with
      | [] -> Ctx.mk_true
      | [phi] -> phi
      | _ -> Ctx.mk_and (List.flatten (List.map conjuncts conjs))
    in
    let pre = conjuncts (mk_and pre) in
    let post = conjuncts (mk_and post) in
    (* Minimal pre condition for post and transition's gaurd by finding unsat core of:
       ~(pre /\ guard => post) <==> pre /\ gaurd /\ ~post *)
    let min_pre post =
      let trans = Ltr.transition_of letter in
      (* Substitute var with it's expression if it appears in the transform *)
      let subst_assign phi =
        let subst sym =
          match Var.of_symbol sym with
          | Some v when Transition.mem_transform v trans -> (Transition.get_transform v trans)
          | _ -> Ctx.mk_const sym
        in
        (substitute_const srk subst phi)
      in
      let post_ass = subst_assign post in
      match pre, (Syntax.destruct srk post_ass) with
      | [], _ -> [Ctx.mk_true]
      | _, `Tru -> [Ctx.mk_true]
      | _, _ ->
         begin
           let z3_solver = SrkZ3.mk_solver srk in
           let assumptions = List.map (fun _ -> Ctx.mk_const (Ctx.mk_symbol `TyBool)) pre in
           let rules = List.map2 (fun pre ass -> Syntax.mk_iff srk pre ass) pre assumptions in
           z3_solver#add ((Ctx.mk_not post_ass) :: (Transition.guard trans) :: rules);
           let rec get_pres ass pres core acc =
             match ass, pres, core with
             | a :: ass, p :: pres, c :: core ->
                begin
                  if (a = c) then
                    get_pres ass pres core (p :: acc)
                  else
                    get_pres ass pres (c :: core) acc
                end
             | _, _, [] -> acc
             | [], p, c -> assert false
             | a, [], c -> assert false
           in
           match z3_solver#get_unsat_core assumptions with
           | `Sat -> assert false
           | `Unknown -> pre
           | `Unsat core -> get_pres assumptions pre core []
         end
    in
    let rec split posts acc =
      match posts with
      | [] -> acc
      | post :: posts ->
         split posts (((min_pre post), letter, [post]) :: acc)
    in
    split post []
end
