Snapshot generated code for monomorphic variants and naming.

  $ cat > input.ml <<'EOF'
  > type t = Main [@@deriving map]
  > type status = Active [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Main [@@deriving map]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec map : t -> t = fun x -> match x with Main -> Main
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving map]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec map_status : status -> status =
     fun x -> match x with Active -> Active
    [@@ocaml.warning "-39"]
  
    let _ = map_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Monomorphic aliases collapse to the identity and impose no map requirement
on the referenced module.

  $ cat > input.ml <<'EOF'
  > module Plain = struct
  >   type t = T of int
  > end
  > 
  > type wrapped = Plain.t [@@deriving map]
  > type many = string list [@@deriving map]
  > type pair = int * bool [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Plain = struct
    type t = T of int
  end
  
  type wrapped = Plain.t [@@deriving map]
  
  include struct
    let _ = fun (_ : wrapped) -> ()
    let rec map_wrapped : wrapped -> wrapped = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_wrapped
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type many = string list [@@deriving map]
  
  include struct
    let _ = fun (_ : many) -> ()
    let rec map_many : many -> many = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_many
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type pair = int * bool [@@deriving map]
  
  include struct
    let _ = fun (_ : pair) -> ()
    let rec map_pair : pair -> pair = fun x -> x [@@ocaml.warning "-39"]
    let _ = map_pair
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
