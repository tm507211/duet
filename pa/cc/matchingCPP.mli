open Pervasives
open BatPervasives
open Apak

module type Symbol = sig
  type t
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val pp : Format.formatter -> t -> unit
end

module type S = sig
  type t
  type predicate

  (* empty embedding problem *)
  val empty : t

  (* prepare embedding problem to be passed to C / C++ *)
  (* Universe1 -> Props1 -> Universe2 -> Props2 -> { RECORD OF DATA } *)
  val make : int -> (predicate * int list) BatEnum.t -> int -> (predicate * int list) BatEnum.t -> t

  (* run the embedding problem in C / C++ *)
  val embeds : t -> bool
  val match_embeds : t -> bool
  val crypto_mini_sat : t -> bool
  val lingeling : t -> bool
  val haifacsp : t -> bool
  val gecode : t -> bool
  val vf2 : t ->  bool
  val ortools : t -> bool
  val emb2mzn : t -> bool
  val emb2dimacs : t -> bool
  val emb2lad : t -> bool
end

module Make (Predicate : Symbol) : S with type predicate = Predicate.t
