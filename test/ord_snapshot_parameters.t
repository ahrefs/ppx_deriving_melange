Snapshot generated code for a parameterized variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Missing
  > [@@deriving ord]
  > 
  > type 'a phantom = Id of int [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Missing [@@deriving ord]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Value a0, Value b0 -> poly_a a0 b0
        | Missing, Missing -> 0
        | _ ->
            let to_int value = match value with Value _ -> 0 | Missing -> 1 in
            Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a phantom = Id of int [@@deriving ord]
  
  include struct
    let _ = fun (_ : 'a phantom) -> ()
  
    let rec compare_phantom : ('a -> 'a -> int) -> 'a phantom -> 'a phantom -> int
        =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Id a0, Id b0 -> (fun (a : int) b -> Stdlib.compare a b) a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = compare_phantom
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a two-parameter record (one comparison callback per
type parameter, applied in field order).

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t = {
  >   first : 'a;
  >   second : 'b;
  > }
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = { first : 'a; second : 'b } [@@deriving ord]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec compare :
        ('a -> 'a -> int) -> ('b -> 'b -> int) -> ('a, 'b) t -> ('a, 'b) t -> int
        =
     fun poly_a ->
      fun poly_b ->
       fun a ->
        fun b ->
         match poly_a a.first b.first with
         | 0 -> poly_b a.second b.second
         | result -> result
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving ord]
  > end
  > 
  > module Item = struct
  >   type t =
  >     | A
  >     | B
  >   [@@deriving ord]
  > end
  > 
  > type t = Item.t Box.t [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving ord]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int =
       fun poly_a ->
        fun a -> fun b -> match (a, b) with Box a0, Box b0 -> poly_a a0 b0
      [@@ocaml.warning "-39"]
  
      let _ = compare
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  module Item = struct
    type t = A | B [@@deriving ord]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec compare : t -> t -> int =
       fun a ->
        fun b ->
         match (a, b) with
         | A, A -> 0
         | B, B -> 0
         | _ ->
             let to_int value = match value with A -> 0 | B -> 1 in
             Stdlib.compare (to_int a) (to_int b)
      [@@ocaml.warning "-39"]
  
      let _ = compare
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type t = Item.t Box.t [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int = Box.compare Item.compare
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported functor-applied type paths produce a clear error.

  $ cat > input.ml <<'EOF'
  > module Arg = struct
  >   let offset = 10
  > end
  > 
  > module Make (Input : sig
  >   val offset : int
  > end) = struct
  >   type t = T of int
  > end
  > 
  > type t = Make(Arg).t [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 11, characters 9-20:
  11 | type t = Make(Arg).t [@@deriving ord]
                ^^^^^^^^^^^
  Error: deriving.ord doesn't support payload type Make(Arg).t
  [1]

Snapshot generated signatures.

  $ cat > input.mli <<'EOF'
  > type 'a t = Value of 'a [@@deriving ord]
  > 
  > type status = Active [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = Value of 'a [@@deriving ord]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving ord]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val compare_status : status -> status -> int
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
