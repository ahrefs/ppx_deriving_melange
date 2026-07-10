Snapshot generated code for two type parameters and a phantom parameter.

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t =
  >   | Left of 'a
  >   | Right of 'b
  > [@@deriving fold]
  > 
  > type 'a phantom = Id of int [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = Left of 'a | Right of 'b [@@deriving fold]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec fold :
        'a 'b 'c. ('c -> 'a -> 'c) -> ('c -> 'b -> 'c) -> 'c -> ('a, 'b) t -> 'c =
     fun poly_a ->
      fun poly_b ->
       fun acc ->
        fun x ->
         match x with Left a0 -> poly_a acc a0 | Right a0 -> poly_b acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a phantom = Id of int [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a phantom) -> ()
  
    let rec fold_phantom : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a phantom -> 'b =
     fun poly_a ->
      fun acc -> fun x -> match x with Id a0 -> (fun acc _ -> acc) acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold_phantom
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving fold]
  > end
  > 
  > type 'a t = 'a Box.t [@@deriving fold]
  > type fixed = int Box.t [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving fold]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
       fun poly_a -> fun acc -> fun x -> match x with Box a0 -> poly_a acc a0
      [@@ocaml.warning "-39"]
  
      let _ = fold
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type 'a t = 'a Box.t [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a -> Box.fold poly_a
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type fixed = int Box.t [@@deriving fold]
  
  include struct
    let _ = fun (_ : fixed) -> ()
  
    let rec fold_fixed : 'a. 'a -> fixed -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_fixed
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

The accumulator variable skips the declared parameter names.

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t =
  >   | First of 'a
  >   | Second of 'b
  > [@@deriving fold]
  > 
  > type ('b, 'c) u =
  >   | Third of 'b
  >   | Fourth of 'c
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = First of 'a | Second of 'b [@@deriving fold]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec fold :
        'a 'b 'c. ('c -> 'a -> 'c) -> ('c -> 'b -> 'c) -> 'c -> ('a, 'b) t -> 'c =
     fun poly_a ->
      fun poly_b ->
       fun acc ->
        fun x ->
         match x with First a0 -> poly_a acc a0 | Second a0 -> poly_b acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type ('b, 'c) u = Third of 'b | Fourth of 'c [@@deriving fold]
  
  include struct
    let _ = fun (_ : ('b, 'c) u) -> ()
  
    let rec fold_u :
        'b 'c 'a. ('a -> 'b -> 'a) -> ('a -> 'c -> 'a) -> 'a -> ('b, 'c) u -> 'a =
     fun poly_b ->
      fun poly_c ->
       fun acc ->
        fun x ->
         match x with Third a0 -> poly_b acc a0 | Fourth a0 -> poly_c acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold_u
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
  > type 'a t = 'a Make(Arg).t [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 8, characters 15-26:
  8 | type 'a t = 'a Make(Arg).t [@@deriving fold]
                     ^^^^^^^^^^^
  Error: deriving.fold doesn't support payload type 'a Make(Arg).t
  [1]

Snapshot generated signatures.

  $ cat > input.mli <<'EOF'
  > type 'a t = Value of 'a [@@deriving fold]
  > type ('a, 'b) pair = Both of 'a * 'b [@@deriving fold]
  > type status = Active [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = Value of 'a [@@deriving fold]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val fold : ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type ('a, 'b) pair = Both of 'a * 'b [@@deriving fold]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val fold_pair :
      ('c -> 'a -> 'c) -> ('c -> 'b -> 'c) -> 'c -> ('a, 'b) pair -> 'c
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving fold]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val fold_status : 'a -> status -> 'a
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
