Snapshot generated code for a parameterized variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Pair of 'a * 'a
  >   | Fixed of string
  >   | Missing
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Pair of 'a * 'a | Fixed of string | Missing
  [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Value a0 -> poly_a a0
       | Pair (a0, a1) ->
           poly_a a0;
           poly_a a1
       | Fixed a0 -> (fun _ -> ()) a0
       | Missing -> ()
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a record payload constructor.

  $ cat > input.ml <<'EOF'
  > type 'a item =
  >   | Item of {
  >       value : 'a;
  >       label : string;
  >     }
  >   | Nothing
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a item = Item of { value : 'a; label : string } | Nothing
  [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a item) -> ()
  
    let rec iter_item : ('a -> unit) -> 'a item -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Item { value = a_value; label = a_label } ->
           poly_a a_value;
           (fun _ -> ()) a_label
       | Nothing -> ()
    [@@ocaml.warning "-39"]
  
    let _ = iter_item
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
