Every rejection path of deriving.fold produces a clear error. Like map,
payload shapes must contain a free type variable to be rejected: a
variable-free payload collapses to the accumulator passthrough before any
shape check runs (pinned at the end of this file).

Fully abstract types have nothing to fold.

  $ cat > input.ml <<'EOF'
  > type t [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-24:
  1 | type t [@@deriving fold]
      ^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.fold doesn't support abstract types
  [1]

Open (extensible) types are rejected.

  $ cat > input.ml <<'EOF'
  > type t = .. [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-29:
  1 | type t = .. [@@deriving fold]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.fold doesn't support open types
  [1]

Non-variable type parameters are rejected.

  $ cat > input.ml <<'EOF'
  > type _ t = T of int [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 5-6:
  1 | type _ t = T of int [@@deriving fold]
           ^
  Error: deriving.fold doesn't support non-variable type parameters
  [1]

Arrow payloads are rejected (there is no way to fold under a function).

  $ cat > input.ml <<'EOF'
  > type 'a t = F of ('a -> int) [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 18-27:
  1 | type 'a t = F of ('a -> int) [@@deriving fold]
                        ^^^^^^^^^
  Error: deriving.fold doesn't support payload type 'a -> int
  [1]

Object types with a type variable are rejected.

  $ cat > input.ml <<'EOF'
  > type 'a t = < width : 'a > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 12-26:
  1 | type 'a t = < width : 'a > [@@deriving fold]
                  ^^^^^^^^^^^^^^
  Error: deriving.fold doesn't support payload type < width: 'a   > 
  [1]

`as`-aliases are rejected (the alias binder counts as a free variable, so
even a variable-free aliased type does not collapse to the passthrough).

  $ cat > input.ml <<'EOF'
  > type t = (int as 'x) [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 10-19:
  1 | type t = (int as 'x) [@@deriving fold]
                ^^^^^^^^^
  Error: deriving.fold doesn't support payload type int as 'x
  [1]

Open polymorphic variants with a type-variable payload are rejected.

  $ cat > input.ml <<'EOF'
  > type 'a t = [> `A of 'a ] [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 12-25:
  1 | type 'a t = [> `A of 'a ] [@@deriving fold]
                  ^^^^^^^^^^^^^
  Error: deriving.fold doesn't support payload type [> `A of 'a ]
  [1]

Universally quantified record fields are rejected.

  $ cat > input.ml <<'EOF'
  > type t = { f : 'a. 'a list } [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 15-26:
  1 | type t = { f : 'a. 'a list } [@@deriving fold]
                     ^^^^^^^^^^^
  Error: deriving.fold doesn't support payload type 'a . 'a list
  [1]

Variable-free shapes that show rejects collapse to the passthrough instead:
a type wildcard and a first-class module expand successfully.

  $ cat > input.ml <<'EOF'
  > module type S = sig
  >   val x : int
  > end
  > 
  > type wild = _ list [@@deriving fold]
  > type packed = (module S) [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module type S = sig
    val x : int
  end
  
  type wild = _ list [@@deriving fold]
  
  include struct
    let _ = fun (_ : wild) -> ()
  
    let rec fold_wild : 'a. 'a -> wild -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_wild
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type packed = (module S) [@@deriving fold]
  
  include struct
    let _ = fun (_ : packed) -> ()
  
    let rec fold_packed : 'a. 'a -> packed -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_packed
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

`ref` (like `lazy_t` and `nativeint`) is not special-cased: expansion
succeeds and references `fold_ref`, which does not exist — so use sites fail
to compile with a normal unbound-value error rather than an expansion-time
one. (Native fold supports `ref`; out of scope here like everywhere else.)

  $ cat > input.ml <<'EOF'
  > type 'a t = 'a ref [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = 'a ref [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a -> fold_ref poly_a
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
