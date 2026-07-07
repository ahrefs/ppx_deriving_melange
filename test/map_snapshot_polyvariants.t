Snapshot generated code for a closed polymorphic variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   [ `All
  >   | `Value of 'a
  >   | `Tagged of string
  >   ]
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = [ `All | `Value of 'a | `Tagged of string ] [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       match x with
       | `All -> `All
       | `Value a -> `Value (poly_a a)
       | `Tagged a -> `Tagged ((fun x -> x) a)
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Polymorphic variant cases with multiple payloads are rejected.

  $ cat > input.ml <<'EOF'
  > type 'a t = [ `Pair of 'a & string ] [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 14-34:
  1 | type 'a t = [ `Pair of 'a & string ] [@@deriving map]
                    ^^^^^^^^^^^^^^^^^^^^
  Error: deriving.map cannot be derived for polymorphic variant cases with multiple payloads
  [1]

Polymorphic variant row inheritance is rejected.

  $ cat > input.ml <<'EOF'
  > type base = [ `A ]
  > type 'a t = [ base | `Value of 'a ] [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 14-18:
  2 | type 'a t = [ base | `Value of 'a ] [@@deriving map]
                    ^^^^
  Error: deriving.map doesn't support inherited polymorphic variant rows
  [1]
