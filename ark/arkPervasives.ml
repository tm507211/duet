open Apak
open BatPervasives

exception Divide_by_zero

module Ring = struct
  module type S = sig
    include Sig.Semiring.S
    val negate : t -> t (* additive inverse *)
    val sub : t -> t -> t
  end
  module Ordered = struct
    module type S = sig
      include S
      include Putil.OrderedMix with type t := t
    end
  end
  module Hashed = struct
    module type S = sig
      include S
      val hash : t -> int
    end
  end
end

module Field = struct
  module type S = sig
    include Ring.S
    val inverse : t -> t (* multiplicative inverse *)
    val div : t -> t -> t
  end
  module Ordered = struct
    module type S = sig
      include S
      include Putil.OrderedMix with type t := t
    end
  end
end

type qq = Mpqf.t (* Rationals *)
type zz = Mpzf.t (* Integers  *)

let opt_default_accuracy = ref (-1)

(* Field of rationals *)
module QQ = struct
  type t = Mpqf.t

  include Putil.MakeFmt(struct
      type a = t
      let format = Mpqf.print
    end)
  module Compare_t = struct
    type a = t
    let compare = Mpqf.cmp
  end
  let show = Show_t.show
  let format = Show_t.format
  let compare = Compare_t.compare
  let add = Mpqf.add
  let sub = Mpqf.sub
  let mul = Mpqf.mul
  let zero = Mpqf.of_int 0
  let div x y =
    if compare y zero = 0 then raise Divide_by_zero
    else Mpqf.div x y

  let one = Mpqf.of_int 1
  let equal = Mpqf.equal
  let negate = Mpqf.neg
  let inverse = Mpqf.inv

  let of_int = Mpqf.of_int
  let of_zz = Mpqf.of_mpz
  let of_frac = Mpqf.of_frac
  let of_zzfrac = Mpqf.of_mpz2
  let of_float = Mpqf.of_float
  let of_string = Mpqf.of_string
  let to_zzfrac = Mpqf.to_mpzf2
  (* unsafe *)
  let to_frac qq =
    let (num,den) = to_zzfrac qq in
    (Mpz.get_int num, Mpz.get_int den)
  let to_zz qq =
    let (num, den) = to_zzfrac qq in
    if Mpz.cmp den (Mpzf.of_int 1) == 0 then Some num
    else None
  let to_float qq = Mpqf.to_float qq

  let numerator = Mpqf.get_num
  let denominator = Mpqf.get_den
  let hash x = Hashtbl.hash (Mpqf.to_string x)
  let leq x y = compare x y <= 0
  let lt x y = compare x y < 0
  let geq x y = compare x y >= 0
  let gt x y = compare x y > 0
  let exp x k =
    let rec go x k =
      if k = 0 then zero
      else if k = 1 then x
      else begin
        let y = go x (k / 2) in
        let y2 = mul y y in
        if k mod 2 = 0 then y2 else mul x y2
      end
    in
    if k < 0 then Mpqf.inv (go x (-k))
    else go x k
  let floor x =
    let (num, den) = to_zzfrac x in
    Mpzf.fdiv_q num den

  let min x y = if leq x y then x else y
  let max x y = if geq x y then x else y
  let abs = Mpqf.abs

  (* Truncated continued fraction *)
  let rec nudge ?(accuracy=(!opt_default_accuracy)) x =
    if accuracy < 0 then
      (x, x)
    else
      let (num, den) = to_zzfrac x in
      let (q, r) = Mpzf.fdiv_qr num den in
      if accuracy = 0 then
        (Mpqf.of_mpz q, Mpqf.of_mpz (Mpzf.add_int q 1))
      else if Mpzf.cmp_int r 0 = 0 then
        (of_zz q, of_zz q)
      else
        let (lo, hi) = nudge ~accuracy:(accuracy - 1) (of_zzfrac den r) in
        (add (of_zz q) (inverse hi),
         add (of_zz q) (inverse lo))

  let rec nudge_down ?(accuracy=(!opt_default_accuracy)) x =
    if accuracy < 0 then
      x
    else
      let (num, den) = to_zzfrac x in
      let (q, r) = Mpzf.fdiv_qr num den in
      if accuracy = 0 then
        Mpqf.of_mpz q
      else if Mpzf.cmp_int r 0 = 0 then
        of_zz q
      else
        let hi = nudge_up ~accuracy:(accuracy - 1) (of_zzfrac den r) in
        add (of_zz q) (inverse hi)
  and nudge_up ?(accuracy=(!opt_default_accuracy)) x =
    if accuracy < 0 then
      x
    else
      let (num, den) = to_zzfrac x in
      let (q, r) = Mpzf.fdiv_qr num den in
      if accuracy = 0 then
        Mpqf.of_mpz (Mpzf.add_int q 1)
      else if Mpzf.cmp_int r 0 = 0 then
        of_zz q
      else
        let lo = nudge_down ~accuracy:(accuracy - 1) (of_zzfrac den r) in
        add (of_zz q) (inverse lo)
end

(* Ring of integers *)
module ZZ = struct
  type t = Mpzf.t

  include Putil.MakeFmt(struct
      type a = t
      let format = Mpzf.print
    end)
  module Compare_t = struct
    type a = t
    let compare = Mpzf.cmp
  end
  let show = Show_t.show
  let format = Show_t.format
  let compare = Compare_t.compare
  let add = Mpzf.add
  let sub = Mpzf.sub
  let mul = Mpzf.mul
  let negate = Mpzf.neg
  let floor_div = Mpzf.fdiv_q

  (* C99: a == (a/b)*b + a%b, division truncates towards zero *)
  let modulo = Mpzf.tdiv_r
  let div = Mpzf.tdiv_q

  let gcd = Mpzf.gcd
  let lcm = Mpzf.lcm

  let of_int = Mpzf.of_int
  let of_string = Mpzf.of_string
  let one = of_int 1
  let zero = of_int 0
  let equal x y = compare x y = 0
  let to_int x =
    if Mpz.fits_int_p x then Some (Mpz.get_int x) else None
  let hash x = Hashtbl.hash (Mpzf.to_string x)
  let leq x y = compare x y <= 0
  let lt x y = compare x y < 0
end

type typ = TyInt | TyReal
             deriving (Compare)

type ('a,'b) open_term =
  | OVar of 'b
  | OConst of QQ.t
  | OAdd of 'a * 'a
  | OMul of 'a * 'a
  | ODiv of 'a * 'a
  | OMod of 'a * 'a
  | OFloor of 'a

type ('a,'b) term_algebra = ('a,'b) open_term -> 'a

type 'a atom =
  | LeqZ of 'a
  | LtZ of 'a
  | EqZ of 'a

type ('a,'b) open_formula =
  | OOr of 'a * 'a
  | OAnd of 'a * 'a
  | OAtom of 'b

type ('a,'b) formula_algebra = ('a,'b) open_formula -> 'a

type pred = Pgt | Pgeq | Plt | Pleq | Peq

let join_typ a b = match a,b with
  | TyInt, TyInt -> TyInt
  | _, _         -> TyReal

module type Var = sig
  include Putil.Ordered
  val typ : t -> typ
end

type 'a affine =
  | AVar of 'a
  | AConst
