Snapshot generated code for monomorphic variants and naming: with no type
parameters there is nothing to fold, so the accumulator passes through.

  $ cat > input.ml <<'EOF'
  > type t = Main [@@deriving fold]
  > type status = Active [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Main [@@deriving fold]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec fold : 'a. 'a -> t -> 'a =
     fun acc -> fun x -> match x with Main -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving fold]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec fold_status : 'a. 'a -> status -> 'a =
     fun acc -> fun x -> match x with Active -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Monomorphic aliases collapse to the accumulator passthrough and impose no
fold requirement on the referenced module.

  $ cat > input.ml <<'EOF'
  > module Plain = struct
  >   type t = T of int
  > end
  > 
  > type wrapped = Plain.t [@@deriving fold]
  > type many = string list [@@deriving fold]
  > type pair = int * bool [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Plain = struct
    type t = T of int
  end
  
  type wrapped = Plain.t [@@deriving fold]
  
  include struct
    let _ = fun (_ : wrapped) -> ()
  
    let rec fold_wrapped : 'a. 'a -> wrapped -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_wrapped
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type many = string list [@@deriving fold]
  
  include struct
    let _ = fun (_ : many) -> ()
  
    let rec fold_many : 'a. 'a -> many -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_many
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type pair = int * bool [@@deriving fold]
  
  include struct
    let _ = fun (_ : pair) -> ()
  
    let rec fold_pair : 'a. 'a -> pair -> 'a = fun acc _ -> acc
    [@@ocaml.warning "-39"]
  
    let _ = fold_pair
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
