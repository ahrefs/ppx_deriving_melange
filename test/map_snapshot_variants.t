Snapshot generated code for a parameterized variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Pair of 'a * 'a
  >   | Fixed of string
  >   | Missing
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Pair of 'a * 'a | Fixed of string | Missing
  [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       match x with
       | Value a0 -> Value (poly_a a0)
       | Pair (a0, a1) -> Pair (poly_a a0, poly_a a1)
       | Fixed a0 -> Fixed ((fun x -> x) a0)
       | Missing -> Missing
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a record payload constructor.

  $ cat > input.ml <<'EOF'
  > type 'a item =
  >   | Item of {
  >       value : 'a;
  >       label : string;
  >     }
  >   | Nothing
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a item = Item of { value : 'a; label : string } | Nothing
  [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a item) -> ()
  
    let rec map_item : ('a -> 'b) -> 'a item -> 'b item =
     fun poly_a ->
      fun x ->
       match x with
       | Item { value = a_value; label = a_label } ->
           Item { value = poly_a a_value; label = (fun x -> x) a_label }
       | Nothing -> Nothing
    [@@ocaml.warning "-39"]
  
    let _ = map_item
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
