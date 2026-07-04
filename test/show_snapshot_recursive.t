Snapshot a recursive parameterized type.

  $ cat > input.ml <<'EOF'
  > type 'a tree =
  >   | Leaf
  >   | Node of 'a tree * 'a * 'a tree
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : 'a tree) -> ()
  
    let rec pp_tree :
        (Stdlib.Format.formatter -> 'a -> unit) ->
        Stdlib.Format.formatter ->
        'a tree ->
        unit =
     fun poly_a ->
      fun fmt ->
       fun x ->
        match x with
        | Leaf -> Stdlib.Format.pp_print_string fmt "Leaf"
        | Node (a0, a1, a2) ->
            Stdlib.Format.fprintf fmt "(@[<2>Node (@,";
            (pp_tree poly_a) fmt a0;
            Stdlib.Format.fprintf fmt ",@ ";
            poly_a fmt a1;
            Stdlib.Format.fprintf fmt ",@ ";
            (pp_tree poly_a) fmt a2;
            Stdlib.Format.fprintf fmt "@,))@]"
    [@@ocaml.warning "-39"]
  
    and show_tree : (Stdlib.Format.formatter -> 'a -> unit) -> 'a tree -> string =
     fun poly_a -> fun x -> Stdlib.Format.asprintf "%a" (pp_tree poly_a) x
    [@@ocaml.warning "-39"]
  
    let _ = pp_tree
    and _ = show_tree
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot a mutually recursive group (one recursive binding group).

  $ cat > input.ml <<'EOF'
  > type tree =
  >   | Leaf of int
  >   | Node of forest
  > 
  > and forest = {
  >   trees : tree list;
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type tree = Leaf of int | Node of forest
  and forest = { trees : tree list } [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : tree) -> ()
    let _ = fun (_ : forest) -> ()
  
    let rec pp_tree : Stdlib.Format.formatter -> tree -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Leaf a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Leaf@ ";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
           Stdlib.Format.fprintf fmt "@])"
       | Node a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Node@ ";
           pp_forest fmt a0;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show_tree : tree -> string =
     fun x ->
      match x with
      | Leaf a0 -> "(Leaf " ^ string_of_int a0 ^ ")"
      | Node a0 -> "(Node " ^ show_forest a0 ^ ")"
    [@@ocaml.warning "-39"]
  
    and pp_forest : Stdlib.Format.formatter -> forest -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "trees";
       (fun fmt x ->
         Stdlib.Format.fprintf fmt "@[<2>[";
         ignore
           (List.fold_left
              (fun sep x ->
                if sep then Stdlib.Format.fprintf fmt ";@ ";
                pp_tree fmt x;
                true)
              false x);
         Stdlib.Format.fprintf fmt "@,]@]")
         fmt x.trees;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show_forest : forest -> string =
     fun x ->
      ("{ " ^ "trees = "
      ^ (fun x -> "[" ^ String.concat "; " (List.map show_tree x) ^ "]") x.trees)
      ^ " }"
    [@@ocaml.warning "-39"]
  
    let _ = pp_tree
    and _ = show_tree
    and _ = pp_forest
    and _ = show_forest
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
