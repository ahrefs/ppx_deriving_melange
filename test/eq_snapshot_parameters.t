Snapshot generated code for a parameterized variant.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Missing
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Missing [@@deriving eq]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool =
     fun poly_a ->
      fun a ->
       fun b ->
        match (a, b) with
        | Value a0, Value b0 -> poly_a a0 b0
        | Missing, Missing -> true
        | Value _0, _ -> false
        | Missing, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving eq]
  > end
  > 
  > module Item = struct
  >   type t =
  >     | A
  >     | B
  >   [@@deriving eq]
  > end
  > 
  > type t = Item.t Box.t [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving eq]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool =
       fun poly_a ->
        fun a -> fun b -> match (a, b) with Box a0, Box b0 -> poly_a a0 b0
      [@@ocaml.warning "-39"]
  
      let _ = equal
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  module Item = struct
    type t = A | B [@@deriving eq]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec equal : t -> t -> bool =
       fun a ->
        fun b ->
         match (a, b) with
         | A, A -> true
         | B, B -> true
         | A, _ -> false
         | B, _ -> false
      [@@ocaml.warning "-39"]
  
      let _ = equal
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type t = Item.t Box.t [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
    let rec equal : t -> t -> bool = Box.equal Item.equal [@@ocaml.warning "-39"]
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application with a tuple type argument.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving eq]
  > end
  > 
  > type t = (int * string) Box.t [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving eq]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool =
       fun poly_a ->
        fun a -> fun b -> match (a, b) with Box a0, Box b0 -> poly_a a0 b0
      [@@ocaml.warning "-39"]
  
      let _ = equal
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type t = (int * string) Box.t [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
      Box.equal (fun left ->
          fun right ->
           match (left, right) with
           | (left0, left1), (right0, right1) ->
               (fun (a : int) b -> a = b) left0 right0
               && (fun (a : string) b -> a = b) left1 right1)
    [@@ocaml.warning "-39"]
  
    let _ = equal
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
  > 
  >   let equal (T a) (T b) = a + Input.offset = b + Input.offset
  > end
  > 
  > type t = Make(Arg).t [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 13, characters 9-20:
  13 | type t = Make(Arg).t [@@deriving eq]
                ^^^^^^^^^^^
  Error: deriving.eq doesn't support payload type Make(Arg).t
  [1]

Snapshot generated names for `t` and non-`t` type declarations.

  $ cat > input.ml <<'EOF'
  > type t = Main [@@deriving eq]
  > type status = Active [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Main [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a -> fun b -> match (a, b) with Main, Main -> true
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving eq]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec equal_status : status -> status -> bool =
     fun a -> fun b -> match (a, b) with Active, Active -> true
    [@@ocaml.warning "-39"]
  
    let _ = equal_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
