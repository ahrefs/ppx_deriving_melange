Snapshot generated code for two type parameters and a phantom parameter.

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t =
  >   | Left of 'a
  >   | Right of 'b
  > [@@deriving map]
  > 
  > type 'a phantom = Id of int [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = Left of 'a | Right of 'b [@@deriving map]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec map :
        'a 'b 'c 'd. ('a -> 'c) -> ('b -> 'd) -> ('a, 'b) t -> ('c, 'd) t =
     fun poly_a ->
      fun poly_b ->
       fun x ->
        match x with Left a0 -> Left (poly_a a0) | Right a0 -> Right (poly_b a0)
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a phantom = Id of int [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a phantom) -> ()
  
    let rec map_phantom : 'a 'b. ('a -> 'b) -> 'a phantom -> 'b phantom =
     fun poly_a -> fun x -> match x with Id a0 -> Id ((fun x -> x) a0)
    [@@ocaml.warning "-39"]
  
    let _ = map_phantom
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving map]
  > end
  > 
  > type 'a t = 'a Box.t [@@deriving map]
  > type fixed = int Box.t [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving map]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t =
       fun poly_a -> fun x -> match x with Box a0 -> Box (poly_a a0)
      [@@ocaml.warning "-39"]
  
      let _ = map
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type 'a t = 'a Box.t [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t = fun poly_a -> Box.map poly_a
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type fixed = int Box.t [@@deriving map]
  
  include struct
    let _ = fun (_ : fixed) -> ()
    let rec map_fixed : fixed -> fixed = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_fixed
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Output type variables skip the declared parameter names.

  $ cat > input.ml <<'EOF'
  > type ('b, 'c) t =
  >   | First of 'b
  >   | Second of 'c
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('b, 'c) t = First of 'b | Second of 'c [@@deriving map]
  
  include struct
    let _ = fun (_ : ('b, 'c) t) -> ()
  
    let rec map :
        'b 'c 'a 'd. ('b -> 'a) -> ('c -> 'd) -> ('b, 'c) t -> ('a, 'd) t =
     fun poly_b ->
      fun poly_c ->
       fun x ->
        match x with
        | First a0 -> First (poly_b a0)
        | Second a0 -> Second (poly_c a0)
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Functor-applied type paths are rejected.

  $ cat > input.ml <<'EOF'
  > module Make (Input : sig
  >   val offset : int
  > end) =
  > struct
  >   type 'a t = T of 'a
  > end
  > 
  > type 'a t = 'a Make(Arg).t [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 8, characters 15-26:
  8 | type 'a t = 'a Make(Arg).t [@@deriving map]
                     ^^^^^^^^^^^
  Error: deriving.map doesn't support payload type 'a Make(Arg).t
  [1]

Snapshot generated signatures.

  $ cat > input.mli <<'EOF'
  > type 'a t = Value of 'a [@@deriving map]
  > type ('a, 'b) pair = Both of 'a * 'b [@@deriving map]
  > type status = Active [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = Value of 'a [@@deriving map]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val map : ('a -> 'b) -> 'a t -> 'b t
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type ('a, 'b) pair = Both of 'a * 'b [@@deriving map]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val map_pair : ('a -> 'c) -> ('b -> 'd) -> ('a, 'b) pair -> ('c, 'd) pair
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving map]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val map_status : status -> status
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
