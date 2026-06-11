Snapshot generated names for `t` and non-`t` type declarations.

  $ cat > input.ml <<'EOF'
  > type t = Main [@@deriving iter]
  > type status = Active [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Main [@@deriving iter]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec iter : t -> unit = fun x -> match x with Main -> ()
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving iter]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec iter_status : status -> unit = fun x -> match x with Active -> ()
    [@@ocaml.warning "-39"]
  
    let _ = iter_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for monomorphic types: with no type variables to visit,
the iterator collapses to a no-op and never references payload iterators
(`Plain` deliberately has no `iter`).

  $ cat > input.ml <<'EOF'
  > module Plain = struct
  >   type t = T of int
  > end
  > 
  > type wrapped = Plain.t [@@deriving iter]
  > type many = string list [@@deriving iter]
  > type pair = int * bool [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Plain = struct
    type t = T of int
  end
  
  type wrapped = Plain.t [@@deriving iter]
  
  include struct
    let _ = fun (_ : wrapped) -> ()
    let rec iter_wrapped : wrapped -> unit = fun _ -> () [@@ocaml.warning "-39"]
    let _ = iter_wrapped
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type many = string list [@@deriving iter]
  
  include struct
    let _ = fun (_ : many) -> ()
    let rec iter_many : many -> unit = fun _ -> () [@@ocaml.warning "-39"]
    let _ = iter_many
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type pair = int * bool [@@deriving iter]
  
  include struct
    let _ = fun (_ : pair) -> ()
    let rec iter_pair : pair -> unit = fun _ -> () [@@ocaml.warning "-39"]
    let _ = iter_pair
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
