Snapshot generated code for a mutually recursive parameterized type group.

  $ cat > input.ml <<'EOF'
  > type 'a rule = {
  >   terms : string list;
  >   search_location : 'a;
  > }
  > and 'a rule_group = {
  >   rules : 'a t list;
  > }
  > and 'a t =
  >   | Rule of 'a rule
  >   | Group of 'a rule_group
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a rule = { terms : string list; search_location : 'a }
  and 'a rule_group = { rules : 'a t list }
  and 'a t = Rule of 'a rule | Group of 'a rule_group [@@deriving eq]
  
  include struct
    let _ = fun (_ : 'a rule) -> ()
    let _ = fun (_ : 'a rule_group) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec equal_rule : ('a -> 'a -> bool) -> 'a rule -> 'a rule -> bool =
     fun poly_a ->
      fun lhs ->
       fun rhs ->
        (let rec loop x y =
           match (x, y) with
           | [], [] -> true
           | a :: x, b :: y -> (fun (a : string) b -> a = b) a b && loop x y
           | [], _head :: _tail -> false
           | _head :: _tail, [] -> false
         in
         fun x y -> loop x y)
          lhs.terms rhs.terms
        && poly_a lhs.search_location rhs.search_location
    [@@ocaml.warning "-39"]
  
    and equal_rule_group :
        ('a -> 'a -> bool) -> 'a rule_group -> 'a rule_group -> bool =
     fun poly_a ->
      fun lhs ->
       fun rhs ->
        (let rec loop x y =
           match (x, y) with
           | [], [] -> true
           | a :: x, b :: y -> (equal poly_a) a b && loop x y
           | [], _head :: _tail -> false
           | _head :: _tail, [] -> false
         in
         fun x y -> loop x y)
          lhs.rules rhs.rules
    [@@ocaml.warning "-39"]
  
    and equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Rule a0, Rule b0 -> (equal_rule poly_a) a0 b0
        | Group a0, Group b0 -> (equal_rule_group poly_a) a0 b0
        | Rule _0, _ -> false
        | Group _0, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal_rule
    and _ = equal_rule_group
    and _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported mutually recursive type groups report the unsupported member payload.

  $ cat > input.ml <<'EOF'
  > type good = Good of bad
  > and bad = Bad of (int * (int -> int))
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 25-35:
  2 | and bad = Bad of (int * (int -> int))
                               ^^^^^^^^^^
  Error: deriving.eq doesn't support payload type int -> int
  [1]
