Snapshot generated code for a closed polymorphic variant.

  $ cat > input.ml <<'EOF'
  > type t =
  >   [ `All
  >   | `Name of string
  >   | `Count of int
  >   ]
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = [ `All | `Name of string | `Count of int ] [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       let to_int value =
         match value with `All -> 0 | `Name _ -> 1 | `Count _ -> 2
       in
       match (a, b) with
       | `All, `All -> 0
       | `Name a, `Name b -> (fun (a : string) b -> Stdlib.compare a b) a b
       | `Count a, `Count b -> (fun (a : int) b -> Stdlib.compare a b) a b
       | `All, _ -> Stdlib.compare (to_int a) (to_int b)
       | `Name _, _ -> Stdlib.compare (to_int a) (to_int b)
       | `Count _, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Inherited polymorphic variant rows produce a clear error.

  $ cat > input.ml <<'EOF'
  > type base = [ `A ]
  > type 'a t = [ base | `Value of 'a ] [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 14-18:
  2 | type 'a t = [ base | `Value of 'a ] [@@deriving ord]
                    ^^^^
  Error: deriving.ord doesn't support inherited polymorphic variant rows
  [1]

Polymorphic variant cases with multiple payloads cannot be derived (a type
variable is required to reach the check).

  $ cat > input.ml <<'EOF'
  > type 'a t = [ `Pair of 'a & string ] [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 14-34:
  1 | type 'a t = [ `Pair of 'a & string ] [@@deriving ord]
                    ^^^^^^^^^^^^^^^^^^^^
  Error: deriving.ord cannot be derived for polymorphic variant cases with multiple payloads
  [1]
