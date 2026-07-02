Snapshot generated code for a recursive type.

  $ cat > input.ml <<'EOF'
  > type 'a tree =
  >   | Leaf
  >   | Node of 'a tree * 'a * 'a tree
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving ord]
  
  include struct
    let _ = fun (_ : 'a tree) -> ()
  
    let rec compare_tree : ('a -> 'a -> int) -> 'a tree -> 'a tree -> int =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Leaf, Leaf -> 0
        | Node (a0, a1, a2), Node (b0, b1, b2) -> (
            match (compare_tree poly_a) a0 b0 with
            | 0 -> (
                match poly_a a1 b1 with
                | 0 -> (compare_tree poly_a) a2 b2
                | result -> result)
            | result -> result)
        | _ ->
            let to_int value = match value with Leaf -> 0 | Node _ -> 1 in
            Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare_tree
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a mutually recursive type group.

  $ cat > input.ml <<'EOF'
  > type 'a rule = {
  >   terms : string list;
  >   search_location : 'a;
  > }
  > 
  > and 'a rule_group = { rules : 'a t list }
  > 
  > and 'a t =
  >   | Rule of 'a rule
  >   | Group of 'a rule_group
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a rule = { terms : string list; search_location : 'a }
  and 'a rule_group = { rules : 'a t list }
  and 'a t = Rule of 'a rule | Group of 'a rule_group [@@deriving ord]
  
  include struct
    let _ = fun (_ : 'a rule) -> ()
    let _ = fun (_ : 'a rule_group) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec compare_rule : ('a -> 'a -> int) -> 'a rule -> 'a rule -> int =
     fun poly_a ->
      fun a ->
       fun b ->
        match
          (let rec loop x y =
             match (x, y) with
             | [], [] -> 0
             | [], _head :: _tail -> -1
             | _head :: _tail, [] -> 1
             | a :: x, b :: y -> (
                 match (fun (a : string) b -> Stdlib.compare a b) a b with
                 | 0 -> loop x y
                 | result -> result)
           in
           fun x y -> loop x y)
            a.terms b.terms
        with
        | 0 -> poly_a a.search_location b.search_location
        | result -> result
    [@@ocaml.warning "-39"]
  
    and compare_rule_group :
        ('a -> 'a -> int) -> 'a rule_group -> 'a rule_group -> int =
     fun poly_a ->
      fun a ->
       fun b ->
        (let rec loop x y =
           match (x, y) with
           | [], [] -> 0
           | [], _head :: _tail -> -1
           | _head :: _tail, [] -> 1
           | a :: x, b :: y -> (
               match (compare poly_a) a b with 0 -> loop x y | result -> result)
         in
         fun x y -> loop x y)
          a.rules b.rules
    [@@ocaml.warning "-39"]
  
    and compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Rule a0, Rule b0 -> (compare_rule poly_a) a0 b0
        | Group a0, Group b0 -> (compare_rule_group poly_a) a0 b0
        | _ ->
            let to_int value = match value with Rule _ -> 0 | Group _ -> 1 in
            Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare_rule
    and _ = compare_rule_group
    and _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
