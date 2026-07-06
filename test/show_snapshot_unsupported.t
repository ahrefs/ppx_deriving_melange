Every rejection path of deriving.show produces a clear error. Fully abstract
types have nothing to print.

  $ cat > input.ml <<'EOF'
  > type t [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-24:
  1 | type t [@@deriving show]
      ^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.show doesn't support abstract types
  [1]

Open (extensible) types are rejected.

  $ cat > input.ml <<'EOF'
  > type t = .. [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-29:
  1 | type t = .. [@@deriving show]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.show doesn't support open types
  [1]

Object types are rejected.

  $ cat > input.ml <<'EOF'
  > type t = < width : int > [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 9-24:
  1 | type t = < width : int > [@@deriving show]
               ^^^^^^^^^^^^^^^
  Error: deriving.show doesn't support payload type < width: int   > 
  [1]

`as`-aliases are rejected.

  $ cat > input.ml <<'EOF'
  > type t = (int as 'x) [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 10-19:
  1 | type t = (int as 'x) [@@deriving show]
                ^^^^^^^^^
  Error: deriving.show doesn't support payload type int as 'x
  [1]

Open polymorphic variants are rejected.

  $ cat > input.ml <<'EOF'
  > type t = [> `A ] [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 9-16:
  1 | type t = [> `A ] [@@deriving show]
               ^^^^^^^
  Error: deriving.show doesn't support payload type [> `A ]
  [1]

Polymorphic variant cases with multiple (conjunctive) payloads are rejected.

  $ cat > input.ml <<'EOF'
  > type t = [ `A of int & string ] [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 11-29:
  1 | type t = [ `A of int & string ] [@@deriving show]
                 ^^^^^^^^^^^^^^^^^^
  Error: deriving.show cannot be derived for polymorphic variant cases with multiple payloads
  [1]

Universally quantified record fields are rejected.

  $ cat > input.ml <<'EOF'
  > type t = { f : 'a. 'a list } [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 15-26:
  1 | type t = { f : 'a. 'a list } [@@deriving show]
                     ^^^^^^^^^^^
  Error: deriving.show doesn't support payload type 'a . 'a list
  [1]

First-class module types are rejected.

  $ cat > input.ml <<'EOF'
  > module type S = sig
  >   val x : int
  > end
  > 
  > type t = (module S) [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 5, characters 9-19:
  5 | type t = (module S) [@@deriving show]
               ^^^^^^^^^^
  Error: deriving.show doesn't support payload type (module S)
  [1]

A type wildcard is rejected.

  $ cat > input.ml <<'EOF'
  > type t = _ list [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 9-10:
  1 | type t = _ list [@@deriving show]
               ^
  Error: deriving.show doesn't support payload type _
  [1]

`ref` (like `lazy_t` and `nativeint`) is not special-cased: expansion succeeds
and references `pp_ref`, which does not exist — so use sites fail to compile
with a normal unbound-value error rather than an expansion-time one.

  $ cat > input.ml <<'EOF'
  > type t = int ref [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = int ref [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt x -> (pp_ref (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x)) fmt x
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
