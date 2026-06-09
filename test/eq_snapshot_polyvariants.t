Snapshot generated code for a closed polymorphic variant.

  $ cat > input.ml <<'EOF'
  > type t =
  >   [ `All
  >   | `Name of string
  >   | `Count of int
  >   ]
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = [ `All | `Name of string | `Count of int ] [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun lhs rhs ->
      match (lhs, rhs) with
      | `All, `All -> true
      | `Name a, `Name b -> (fun (a : string) b -> a = b) a b
      | `Count a, `Count b -> (fun (a : int) b -> a = b) a b
      | `All, _ -> false
      | `Name _, _ -> false
      | `Count _, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported polymorphic variant inheritance reports a clear error.

  $ cat > input.ml <<'EOF'
  > type base = [ `Base ] [@@deriving eq]
  > type t = [ base | `Extra ] [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 11-15:
  2 | type t = [ base | `Extra ] [@@deriving eq]
                 ^^^^
  Error: deriving.eq doesn't support inherited polymorphic variant rows
  [1]

Unsupported polymorphic variant cases with multiple payloads report a clear error.

  $ cat > input.ml <<'EOF'
  > type t = [ `Pair of int & string ] [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 11-32:
  1 | type t = [ `Pair of int & string ] [@@deriving eq]
                 ^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.eq doesn't support polymorphic variant cases with multiple payloads
  [1]
