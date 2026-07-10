Snapshot generated code for a parameterized variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Pair of 'a * 'a
  >   | Fixed of string
  >   | Missing
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Pair of 'a * 'a | Fixed of string | Missing
  [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Value a0 -> poly_a acc a0
        | Pair (a0, a1) ->
            let acc = poly_a acc a0 in
            poly_a acc a1
        | Fixed a0 -> (fun acc _ -> acc) acc a0
        | Missing -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a record payload constructor.

  $ cat > input.ml <<'EOF'
  > type 'a item =
  >   | Item of {
  >       value : 'a;
  >       label : string;
  >     }
  >   | Nothing
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a item = Item of { value : 'a; label : string } | Nothing
  [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a item) -> ()
  
    let rec fold_item : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a item -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Item { value = a_value; label = a_label } ->
            let acc = poly_a acc a_value in
            (fun acc _ -> acc) acc a_label
        | Nothing -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_item
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
