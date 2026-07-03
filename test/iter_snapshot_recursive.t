Snapshot generated code for a recursive type.

  $ cat > input.ml <<'EOF'
  > type 'a tree =
  >   | Leaf
  >   | Node of 'a tree * 'a * 'a tree
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a tree) -> ()
  
    let rec iter_tree : ('a -> unit) -> 'a tree -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Leaf -> ()
       | Node (a0, a1, a2) ->
           (iter_tree poly_a) a0;
           poly_a a1;
           (iter_tree poly_a) a2
    [@@ocaml.warning "-39"]
  
    let _ = iter_tree
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a recursive type with an inline record payload.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Leaf
  >   | Node of {
  >       left : 'a t;
  >       value : 'a;
  >       right : 'a t;
  >     }
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Leaf | Node of { left : 'a t; value : 'a; right : 'a t }
  [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Leaf -> ()
       | Node { left = a_left; value = a_value; right = a_right } ->
           (iter poly_a) a_left;
           poly_a a_value;
           (iter poly_a) a_right
    [@@ocaml.warning "-39"]
  
    let _ = iter
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
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a rule = { terms : string list; search_location : 'a }
  and 'a rule_group = { rules : 'a t list }
  and 'a t = Rule of 'a rule | Group of 'a rule_group [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a rule) -> ()
    let _ = fun (_ : 'a rule_group) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter_rule : ('a -> unit) -> 'a rule -> unit =
     fun poly_a ->
      fun x ->
       (fun _ -> ()) x.terms;
       poly_a x.search_location
    [@@ocaml.warning "-39"]
  
    and iter_rule_group : ('a -> unit) -> 'a rule_group -> unit =
     fun poly_a -> fun x -> (List.iter (iter poly_a)) x.rules
    [@@ocaml.warning "-39"]
  
    and iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Rule a0 -> (iter_rule poly_a) a0
       | Group a0 -> (iter_rule_group poly_a) a0
    [@@ocaml.warning "-39"]
  
    let _ = iter_rule
    and _ = iter_rule_group
    and _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

iter needs no eta-expansion for same-group aliases: a monomorphic alias
collapses to the no-op lambda, and a parameterized alias is wrapped by its
type-parameter callbacks.

  $ cat > input.ml <<'EOF2'
  > type a = A of int
  > and b = a [@@deriving iter]
  > 
  > type 'a pair = 'a * 'a
  > and 'a t = 'a pair [@@deriving iter]
  > EOF2
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type a = A of int
  and b = a [@@deriving iter]
  
  include struct
    let _ = fun (_ : a) -> ()
    let _ = fun (_ : b) -> ()
  
    let rec iter_a : a -> unit = fun x -> match x with A a0 -> (fun _ -> ()) a0
    [@@ocaml.warning "-39"]
  
    and iter_b : b -> unit = fun _ -> () [@@ocaml.warning "-39"]
  
    let _ = iter_a
    and _ = iter_b
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a pair = 'a * 'a
  and 'a t = 'a pair [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a pair) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter_pair : ('a -> unit) -> 'a pair -> unit =
     fun poly_a ->
      fun (a0, a1) ->
       poly_a a0;
       poly_a a1
    [@@ocaml.warning "-39"]
  
    and iter : ('a -> unit) -> 'a t -> unit = fun poly_a -> iter_pair poly_a
    [@@ocaml.warning "-39"]
  
    let _ = iter_pair
    and _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
