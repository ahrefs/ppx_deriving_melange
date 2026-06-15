Snapshot generated code for multiple and phantom type parameters.

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t =
  >   | Left of 'a
  >   | Right of 'b
  > [@@deriving iter]
  > 
  > type 'a phantom = Id of int [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = Left of 'a | Right of 'b [@@deriving iter]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec iter : ('a -> unit) -> ('b -> unit) -> ('a, 'b) t -> unit =
     fun poly_a ->
      fun poly_b ->
       fun x -> match x with Left a0 -> poly_a a0 | Right a0 -> poly_b a0
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a phantom = Id of int [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a phantom) -> ()
  
    let rec iter_phantom : ('a -> unit) -> 'a phantom -> unit =
     fun poly_a -> fun x -> match x with Id a0 -> (fun _ -> ()) a0
    [@@ocaml.warning "-39"]
  
    let _ = iter_phantom
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for generic type applications: a parameterized
application references `Box.iter`, a monomorphic one collapses to a no-op.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving iter]
  > end
  > 
  > type 'a t = 'a Box.t [@@deriving iter]
  > type fixed = int Box.t [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving iter]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec iter : ('a -> unit) -> 'a t -> unit =
       fun poly_a -> fun x -> match x with Box a0 -> poly_a a0
      [@@ocaml.warning "-39"]
  
      let _ = iter
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type 'a t = 'a Box.t [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit = fun poly_a -> Box.iter poly_a
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type fixed = int Box.t [@@deriving iter]
  
  include struct
    let _ = fun (_ : fixed) -> ()
    let rec iter_fixed : fixed -> unit = fun _ -> () [@@ocaml.warning "-39"]
    let _ = iter_fixed
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A monomorphic functor-applied path has no type variables, so it collapses to
the no-op before the functor check fires, as native ppx_deriving.iter does.

  $ cat > input.ml <<'EOF'
  > module Arg = struct
  >   let offset = 10
  > end
  > 
  > module Make (Input : sig
  >   val offset : int
  > end) = struct
  >   type 'a t = T of 'a
  > end
  > 
  > type t = Make(Arg).t [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Arg = struct
    let offset = 10
  end
  
  module Make (Input : sig
    val offset : int
  end) =
  struct
    type 'a t = T of 'a
  end
  
  type t = Make(Arg).t [@@deriving iter]
  
  include struct
    let _ = fun (_ : t) -> ()
    let rec iter : t -> unit = fun _ -> () [@@ocaml.warning "-39"]
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Functor-applied type paths that are actually reached (a type variable forces
traversal) produce a clear error.

  $ cat > input.ml <<'EOF'
  > module Arg = struct
  >   let offset = 10
  > end
  > 
  > module Make (Input : sig
  >   val offset : int
  > end) = struct
  >   type 'a t = T of 'a
  > end
  > 
  > type 'a t = 'a Make(Arg).t [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 11, characters 15-26:
  11 | type 'a t = 'a Make(Arg).t [@@deriving iter]
                      ^^^^^^^^^^^
  Error: deriving.iter doesn't support payload type 'a Make(Arg).t
  [1]

Snapshot generated signatures.

  $ cat > input.mli <<'EOF'
  > type 'a t = Value of 'a [@@deriving iter]
  > 
  > type status = Active [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = Value of 'a [@@deriving iter]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val iter : ('a -> unit) -> 'a t -> unit
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving iter]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val iter_status : status -> unit
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
