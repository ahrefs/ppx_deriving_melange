Every rejection path of deriving.map produces a clear error. Unlike show,
payload shapes must contain a free type variable to be rejected: a
variable-free payload collapses to the identity mapper before any shape
check runs (pinned at the end of this file).

Fully abstract types have nothing to map.

  $ cat > input.ml <<'EOF'
  > type t [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-23:
  1 | type t [@@deriving map]
      ^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.map doesn't support abstract types
  [1]

Open (extensible) types are rejected.

  $ cat > input.ml <<'EOF'
  > type t = .. [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-28:
  1 | type t = .. [@@deriving map]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.map doesn't support open types
  [1]

Non-variable type parameters are rejected.

  $ cat > input.ml <<'EOF'
  > type _ t = T of int [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 5-6:
  1 | type _ t = T of int [@@deriving map]
           ^
  Error: deriving.map doesn't support non-variable type parameters
  [1]

Arrow payloads are rejected (there is no way to map under a function).

  $ cat > input.ml <<'EOF'
  > type 'a t = F of ('a -> int) [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 18-27:
  1 | type 'a t = F of ('a -> int) [@@deriving map]
                        ^^^^^^^^^
  Error: deriving.map doesn't support payload type 'a -> int
  [1]

Object types with a type variable are rejected.

  $ cat > input.ml <<'EOF'
  > type 'a t = < width : 'a > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 12-26:
  1 | type 'a t = < width : 'a > [@@deriving map]
                  ^^^^^^^^^^^^^^
  Error: deriving.map doesn't support payload type < width: 'a   > 
  [1]

`as`-aliases are rejected (the alias binder counts as a free variable, so
even a variable-free aliased type does not collapse to the identity).

  $ cat > input.ml <<'EOF'
  > type t = (int as 'x) [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 10-19:
  1 | type t = (int as 'x) [@@deriving map]
                ^^^^^^^^^
  Error: deriving.map doesn't support payload type int as 'x
  [1]

Open polymorphic variants with a type-variable payload are rejected.

  $ cat > input.ml <<'EOF'
  > type 'a t = [> `A of 'a ] [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 12-25:
  1 | type 'a t = [> `A of 'a ] [@@deriving map]
                  ^^^^^^^^^^^^^
  Error: deriving.map doesn't support payload type [> `A of 'a ]
  [1]

Universally quantified record fields are rejected.

  $ cat > input.ml <<'EOF'
  > type t = { f : 'a. 'a list } [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 15-26:
  1 | type t = { f : 'a. 'a list } [@@deriving map]
                     ^^^^^^^^^^^
  Error: deriving.map doesn't support payload type 'a . 'a list
  [1]

Variable-free shapes that show rejects collapse to the identity instead: a
type wildcard and a first-class module expand successfully.

  $ cat > input.ml <<'EOF'
  > module type S = sig
  >   val x : int
  > end
  > 
  > type wild = _ list [@@deriving map]
  > type packed = (module S) [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module type S = sig
    val x : int
  end
  
  type wild = _ list [@@deriving map]
  
  include struct
    let _ = fun (_ : wild) -> ()
    let rec map_wild : wild -> wild = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_wild
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type packed = (module S) [@@deriving map]
  
  include struct
    let _ = fun (_ : packed) -> ()
    let rec map_packed : packed -> packed = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_packed
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

`ref` (like `lazy_t` and `nativeint`) is not special-cased: expansion
succeeds and references `map_ref`, which does not exist — so use sites fail
to compile with a normal unbound-value error rather than an expansion-time
one.

  $ cat > input.ml <<'EOF'
  > type 'a t = 'a ref [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = 'a ref [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t = fun poly_a -> map_ref poly_a
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
