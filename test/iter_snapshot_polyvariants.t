Snapshot generated code for a closed polymorphic variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   [ `All
  >   | `Value of 'a
  >   | `Tagged of string
  >   ]
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = [ `All | `Value of 'a | `Tagged of string ] [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | `All -> ()
       | `Value a -> poly_a a
       | `Tagged a -> (fun _ -> ()) a
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Polymorphic variant cases with multiple payloads cannot be derived (a type
variable is required to reach the check: a monomorphic case collapses to the
no-op first).

  $ cat > input.ml <<'EOF'
  > type 'a t = [ `Pair of 'a & string ] [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 14-34:
  1 | type 'a t = [ `Pair of 'a & string ] [@@deriving iter]
                    ^^^^^^^^^^^^^^^^^^^^
  Error: deriving.iter cannot be derived for polymorphic variant cases with multiple payloads
  [1]

Inherited polymorphic variant rows produce a clear error.

  $ cat > input.ml <<'EOF'
  > type base = [ `A ]
  > type 'a t = [ base | `Value of 'a ] [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 14-18:
  2 | type 'a t = [ base | `Value of 'a ] [@@deriving iter]
                    ^^^^
  Error: deriving.iter doesn't support inherited polymorphic variant rows
  [1]
