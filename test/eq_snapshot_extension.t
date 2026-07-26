The [%eq: ...] expression extension expands to the same expression the
deriver generates in payload position, for any closed type.

  $ cat > input.ml <<'EOF'
  > module Foo = struct
  >   type t = { x : int } [@@deriving eq]
  > end
  > 
  > let primitive = [%eq: int]
  > let composed = [%eq: (int * string) option]
  > let referenced = [%eq: Foo.t]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Foo = struct
    type t = { x : int } [@@deriving eq]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec equal : t -> t -> bool =
       fun lhs -> fun rhs -> (fun (a : int) b -> a = b) lhs.x rhs.x
      [@@ocaml.warning "-39"]
  
      let _ = equal
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  let primitive (a : int) b = a = b
  
  let composed x y =
    match (x, y) with
    | None, None -> true
    | Some a, Some b ->
        (fun left ->
          fun right ->
           match (left, right) with
           | (left0, left1), (right0, right1) ->
               (fun (a : int) b -> a = b) left0 right0
               && (fun (a : string) b -> a = b) left1 right1)
          a b
    | None, Some _value -> false
    | Some _value, None -> false
  
  let referenced = Foo.equal

Result types work inline too (native tests this shape explicitly).

  $ cat > input.ml <<'EOF'
  > let outcome = [%eq: (string, int) result]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let outcome x y =
    match (x, y) with
    | Ok a, Ok b -> (fun (a : string) b -> a = b) a b
    | Error a, Error b -> (fun (a : int) b -> a = b) a b
    | Ok _value, Error _error -> false
    | Error _error, Ok _value -> false

The namespaced [%derive.eq: ...] form expands identically.

  $ cat > input.ml <<'EOF'
  > let prefixed = [%derive.eq: int list]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let prefixed =
    let rec loop x y =
      match (x, y) with
      | [], [] -> true
      | a :: x, b :: y -> (fun (a : int) b -> a = b) a b && loop x y
      | [], _head :: _tail -> false
      | _head :: _tail, [] -> false
    in
    fun x y -> loop x y

Free type variables are rejected: there is no `poly_a` callback in scope at an
expression, so the type must be closed.

  $ cat > input.ml <<'EOF'
  > let unbound = [%eq: 'a list]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 20-27:
  1 | let unbound = [%eq: 'a list]
                          ^^^^^^^
  Error: deriving.eq doesn't support free type variables in [%eq: ...]
  [1]

Payload shapes the deriver rejects are rejected in the extension too.

  $ cat > input.ml <<'EOF'
  > let arrow = [%eq: int -> int]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 18-28:
  1 | let arrow = [%eq: int -> int]
                        ^^^^^^^^^^
  Error: deriving.eq doesn't support payload type int -> int
  [1]
