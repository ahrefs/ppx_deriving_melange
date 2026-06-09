Snapshot generated code for a custom module payload.

  $ cat > input.ml <<'EOF'
  > module Custom = struct
  >   type t = T of int
  > 
  >   let equal (T a) (T b) = a = b
  > end
  > 
  > type t = CustomPayload of Custom.t [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Custom = struct
    type t = T of int
  
    let equal (T a) (T b) = a = b
  end
  
  type t = CustomPayload of Custom.t [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | CustomPayload a0, CustomPayload b0 -> Custom.equal a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a custom equality payload attribute.

  $ cat > input.ml <<'EOF'
  > let equal_by_length a b = String.length a = String.length b
  > 
  > type t =
  >   | ByLength of (string [@equal equal_by_length])
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let equal_by_length a b = String.length a = String.length b
  
  type t = ByLength of (string[@equal equal_by_length]) [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with ByLength a0, ByLength b0 -> equal_by_length a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
