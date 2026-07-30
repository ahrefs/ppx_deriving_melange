The [%ord: ...] expression extension expands to the same expression the
deriver generates in payload position, for any closed type.

  $ cat > input.ml <<'EOF'
  > module Foo = struct
  >   type t = { x : int } [@@deriving ord]
  > end
  > 
  > let primitive = [%ord: int]
  > let composed = [%ord: int * string]
  > let referenced = [%ord: Foo.t]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Foo = struct
    type t = { x : int } [@@deriving ord]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec compare : t -> t -> int =
       fun a -> fun b -> (fun (a : int) b -> Stdlib.compare a b) a.x b.x
      [@@ocaml.warning "-39"]
  
      let _ = compare
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  let primitive (a : int) b = Stdlib.compare a b
  
  let composed (a0, a1) =
   fun (b0, b1) ->
    match (fun (a : int) b -> Stdlib.compare a b) a0 b0 with
    | 0 -> (fun (a : string) b -> Stdlib.compare a b) a1 b1
    | result -> result
  
  let referenced = Foo.compare

Result types work inline too (native tests this shape explicitly).

  $ cat > input.ml <<'EOF'
  > let outcome = [%ord: (unit, unit) result]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let outcome x y =
    match (x, y) with
    | Error a, Error b -> (fun (a : unit) b -> Stdlib.compare a b) a b
    | Ok a, Ok b -> (fun (a : unit) b -> Stdlib.compare a b) a b
    | Ok _value, Error _error -> -1
    | Error _error, Ok _value -> 1

The namespaced [%derive.ord: ...] form expands identically.

  $ cat > input.ml <<'EOF'
  > let prefixed = [%derive.ord: int list]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let prefixed =
    let rec loop x y =
      match (x, y) with
      | [], [] -> 0
      | [], _head :: _tail -> -1
      | _head :: _tail, [] -> 1
      | a :: x, b :: y -> (
          match (fun (a : int) b -> Stdlib.compare a b) a b with
          | 0 -> loop x y
          | result -> result)
    in
    fun x y -> loop x y

Free type variables are rejected.

  $ cat > input.ml <<'EOF'
  > let unbound = [%ord: 'a option]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 21-30:
  1 | let unbound = [%ord: 'a option]
                           ^^^^^^^^^
  Error: deriving.ord doesn't support free type variables ('a) in [%ord: ...]
  [1]

[%compare: ...] is deliberately not registered (native has no such extension,
and ppx_compare owns that name in many pipelines), so it passes through
unexpanded.

  $ cat > input.ml <<'EOF'
  > let not_ours = [%compare: int]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let not_ours = [%compare: int]
