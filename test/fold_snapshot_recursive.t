Snapshot generated code for a recursive type.

  $ cat > input.ml <<'EOF'
  > type 'a tree =
  >   | Leaf
  >   | Node of 'a tree * 'a * 'a tree
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a tree) -> ()
  
    let rec fold_tree : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a tree -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Leaf -> acc
        | Node (a0, a1, a2) ->
            let acc = (fold_tree poly_a) acc a0 in
            let acc = poly_a acc a1 in
            (fold_tree poly_a) acc a2
    [@@ocaml.warning "-39"]
  
    let _ = fold_tree
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
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a rule = { terms : string list; search_location : 'a }
  and 'a rule_group = { rules : 'a t list }
  and 'a t = Rule of 'a rule | Group of 'a rule_group [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a rule) -> ()
    let _ = fun (_ : 'a rule_group) -> ()
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold_rule : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a rule -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        let acc = (fun acc _ -> acc) acc x.terms in
        poly_a acc x.search_location
    [@@ocaml.warning "-39"]
  
    and fold_rule_group : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a rule_group -> 'b =
     fun poly_a -> fun acc -> fun x -> (List.fold_left (fold poly_a)) acc x.rules
    [@@ocaml.warning "-39"]
  
    and fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Rule a0 -> (fold_rule poly_a) acc a0
        | Group a0 -> (fold_rule_group poly_a) acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold_rule
    and _ = fold_rule_group
    and _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
