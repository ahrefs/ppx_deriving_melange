Snapshot generated code for a recursive type.

  $ cat > input.ml <<'EOF'
  > type 'a tree =
  >   | Leaf
  >   | Node of 'a tree * 'a * 'a tree
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a tree) -> ()
  
    let rec map_tree : ('a -> 'b) -> 'a tree -> 'b tree =
     fun poly_a ->
      fun x ->
       match x with
       | Leaf -> Leaf
       | Node (a0, a1, a2) ->
           Node ((map_tree poly_a) a0, poly_a a1, (map_tree poly_a) a2)
    [@@ocaml.warning "-39"]
  
    let _ = map_tree
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
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a rule = { terms : string list; search_location : 'a }
  and 'a rule_group = { rules : 'a t list }
  and 'a t = Rule of 'a rule | Group of 'a rule_group [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a rule) -> ()
    let _ = fun (_ : 'a rule_group) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec map_rule : ('a -> 'b) -> 'a rule -> 'b rule =
     fun poly_a ->
      fun x ->
       {
         terms = (fun x -> x) x.terms;
         search_location = poly_a x.search_location;
       }
    [@@ocaml.warning "-39"]
  
    and map_rule_group : ('a -> 'b) -> 'a rule_group -> 'b rule_group =
     fun poly_a -> fun x -> { rules = (List.map (map poly_a)) x.rules }
    [@@ocaml.warning "-39"]
  
    and map : ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       match x with
       | Rule a0 -> Rule ((map_rule poly_a) a0)
       | Group a0 -> Group ((map_rule_group poly_a) a0)
    [@@ocaml.warning "-39"]
  
    let _ = map_rule
    and _ = map_rule_group
    and _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
