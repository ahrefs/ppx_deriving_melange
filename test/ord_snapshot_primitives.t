Snapshot generated code for primitive payloads (typed Stdlib.compare).

  $ cat > input.ml <<'EOF'
  > type t =
  >   | StringPayload of string
  >   | IntPayload of int
  >   | BoolPayload of bool
  >   | FloatPayload of float
  >   | CharPayload of char
  >   | BytesPayload of bytes
  >   | Int32Payload of int32
  >   | QualifiedInt32Payload of Int32.t
  >   | Int64Payload of int64
  >   | QualifiedInt64Payload of Int64.t
  >   | UnitPayload of unit
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | StringPayload of string
    | IntPayload of int
    | BoolPayload of bool
    | FloatPayload of float
    | CharPayload of char
    | BytesPayload of bytes
    | Int32Payload of int32
    | QualifiedInt32Payload of Int32.t
    | Int64Payload of int64
    | QualifiedInt64Payload of Int64.t
    | UnitPayload of unit
  [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match (a, b) with
       | StringPayload a0, StringPayload b0 ->
           (fun (a : string) b -> Stdlib.compare a b) a0 b0
       | IntPayload a0, IntPayload b0 ->
           (fun (a : int) b -> Stdlib.compare a b) a0 b0
       | BoolPayload a0, BoolPayload b0 ->
           (fun (a : bool) b -> Stdlib.compare a b) a0 b0
       | FloatPayload a0, FloatPayload b0 ->
           (fun (a : float) b -> Stdlib.compare a b) a0 b0
       | CharPayload a0, CharPayload b0 ->
           (fun (a : char) b -> Stdlib.compare a b) a0 b0
       | BytesPayload a0, BytesPayload b0 ->
           (fun (a : bytes) b -> Stdlib.compare a b) a0 b0
       | Int32Payload a0, Int32Payload b0 ->
           (fun (a : int32) b -> Stdlib.compare a b) a0 b0
       | QualifiedInt32Payload a0, QualifiedInt32Payload b0 ->
           (fun (a : Int32.t) b -> Stdlib.compare a b) a0 b0
       | Int64Payload a0, Int64Payload b0 ->
           (fun (a : int64) b -> Stdlib.compare a b) a0 b0
       | QualifiedInt64Payload a0, QualifiedInt64Payload b0 ->
           (fun (a : Int64.t) b -> Stdlib.compare a b) a0 b0
       | UnitPayload a0, UnitPayload b0 ->
           (fun (a : unit) b -> Stdlib.compare a b) a0 b0
       | _ ->
           let to_int value =
             match value with
             | StringPayload _ -> 0
             | IntPayload _ -> 1
             | BoolPayload _ -> 2
             | FloatPayload _ -> 3
             | CharPayload _ -> 4
             | BytesPayload _ -> 5
             | Int32Payload _ -> 6
             | QualifiedInt32Payload _ -> 7
             | Int64Payload _ -> 8
             | QualifiedInt64Payload _ -> 9
             | UnitPayload _ -> 10
           in
           Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for primitive aliases.

  $ cat > input.ml <<'EOF'
  > type string_alias = string [@@deriving ord]
  > type int_alias = int [@@deriving ord]
  > type bool_alias = bool [@@deriving ord]
  > type float_alias = float [@@deriving ord]
  > type char_alias = char [@@deriving ord]
  > type bytes_alias = bytes [@@deriving ord]
  > type int32_alias = int32 [@@deriving ord]
  > type qualified_int32_alias = Int32.t [@@deriving ord]
  > type int64_alias = int64 [@@deriving ord]
  > type qualified_int64_alias = Int64.t [@@deriving ord]
  > type unit_alias = unit [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type string_alias = string [@@deriving ord]
  
  include struct
    let _ = fun (_ : string_alias) -> ()
  
    let rec compare_string_alias : string_alias -> string_alias -> int =
     fun (a : string) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_string_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type int_alias = int [@@deriving ord]
  
  include struct
    let _ = fun (_ : int_alias) -> ()
  
    let rec compare_int_alias : int_alias -> int_alias -> int =
     fun (a : int) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_int_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type bool_alias = bool [@@deriving ord]
  
  include struct
    let _ = fun (_ : bool_alias) -> ()
  
    let rec compare_bool_alias : bool_alias -> bool_alias -> int =
     fun (a : bool) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_bool_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type float_alias = float [@@deriving ord]
  
  include struct
    let _ = fun (_ : float_alias) -> ()
  
    let rec compare_float_alias : float_alias -> float_alias -> int =
     fun (a : float) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_float_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type char_alias = char [@@deriving ord]
  
  include struct
    let _ = fun (_ : char_alias) -> ()
  
    let rec compare_char_alias : char_alias -> char_alias -> int =
     fun (a : char) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_char_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type bytes_alias = bytes [@@deriving ord]
  
  include struct
    let _ = fun (_ : bytes_alias) -> ()
  
    let rec compare_bytes_alias : bytes_alias -> bytes_alias -> int =
     fun (a : bytes) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_bytes_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type int32_alias = int32 [@@deriving ord]
  
  include struct
    let _ = fun (_ : int32_alias) -> ()
  
    let rec compare_int32_alias : int32_alias -> int32_alias -> int =
     fun (a : int32) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_int32_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type qualified_int32_alias = Int32.t [@@deriving ord]
  
  include struct
    let _ = fun (_ : qualified_int32_alias) -> ()
  
    let rec compare_qualified_int32_alias :
        qualified_int32_alias -> qualified_int32_alias -> int =
     fun (a : Int32.t) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_qualified_int32_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type int64_alias = int64 [@@deriving ord]
  
  include struct
    let _ = fun (_ : int64_alias) -> ()
  
    let rec compare_int64_alias : int64_alias -> int64_alias -> int =
     fun (a : int64) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_int64_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type qualified_int64_alias = Int64.t [@@deriving ord]
  
  include struct
    let _ = fun (_ : qualified_int64_alias) -> ()
  
    let rec compare_qualified_int64_alias :
        qualified_int64_alias -> qualified_int64_alias -> int =
     fun (a : Int64.t) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_qualified_int64_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type unit_alias = unit [@@deriving ord]
  
  include struct
    let _ = fun (_ : unit_alias) -> ()
  
    let rec compare_unit_alias : unit_alias -> unit_alias -> int =
     fun (a : unit) b -> Stdlib.compare a b
    [@@ocaml.warning "-39"]
  
    let _ = compare_unit_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
