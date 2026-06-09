Snapshot generated code for primitive payloads and aliases.

  $ cat > input.ml <<'EOF'
  > type primitive_payload =
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
  > [@@deriving eq]
  > 
  > type int_alias = int [@@deriving eq]
  > type int32_alias = int32 [@@deriving eq]
  > type bytes_alias = bytes [@@deriving eq]
  > type string_alias = string [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type primitive_payload =
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
  [@@deriving eq]
  
  include struct
    let _ = fun (_ : primitive_payload) -> ()
  
    let rec equal_primitive_payload :
        primitive_payload -> primitive_payload -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | StringPayload a0, StringPayload b0 -> (fun (a : string) b -> a = b) a0 b0
       | IntPayload a0, IntPayload b0 -> (fun (a : int) b -> a = b) a0 b0
       | BoolPayload a0, BoolPayload b0 -> (fun (a : bool) b -> a = b) a0 b0
       | FloatPayload a0, FloatPayload b0 -> (fun (a : float) b -> a = b) a0 b0
       | CharPayload a0, CharPayload b0 -> (fun (a : char) b -> a = b) a0 b0
       | BytesPayload a0, BytesPayload b0 -> (fun (a : bytes) b -> a = b) a0 b0
       | Int32Payload a0, Int32Payload b0 -> (fun (a : int32) b -> a = b) a0 b0
       | QualifiedInt32Payload a0, QualifiedInt32Payload b0 ->
           (fun (a : Int32.t) b -> a = b) a0 b0
       | Int64Payload a0, Int64Payload b0 -> (fun (a : int64) b -> a = b) a0 b0
       | QualifiedInt64Payload a0, QualifiedInt64Payload b0 ->
           (fun (a : Int64.t) b -> a = b) a0 b0
       | StringPayload _0, _ -> false
       | IntPayload _0, _ -> false
       | BoolPayload _0, _ -> false
       | FloatPayload _0, _ -> false
       | CharPayload _0, _ -> false
       | BytesPayload _0, _ -> false
       | Int32Payload _0, _ -> false
       | QualifiedInt32Payload _0, _ -> false
       | Int64Payload _0, _ -> false
       | QualifiedInt64Payload _0, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal_primitive_payload
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type int_alias = int [@@deriving eq]
  
  include struct
    let _ = fun (_ : int_alias) -> ()
  
    let rec equal_int_alias : int_alias -> int_alias -> bool =
     fun (a : int) b -> a = b
    [@@ocaml.warning "-39"]
  
    let _ = equal_int_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type int32_alias = int32 [@@deriving eq]
  
  include struct
    let _ = fun (_ : int32_alias) -> ()
  
    let rec equal_int32_alias : int32_alias -> int32_alias -> bool =
     fun (a : int32) b -> a = b
    [@@ocaml.warning "-39"]
  
    let _ = equal_int32_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type bytes_alias = bytes [@@deriving eq]
  
  include struct
    let _ = fun (_ : bytes_alias) -> ()
  
    let rec equal_bytes_alias : bytes_alias -> bytes_alias -> bool =
     fun (a : bytes) b -> a = b
    [@@ocaml.warning "-39"]
  
    let _ = equal_bytes_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type string_alias = string [@@deriving eq]
  
  include struct
    let _ = fun (_ : string_alias) -> ()
  
    let rec equal_string_alias : string_alias -> string_alias -> bool =
     fun (a : string) b -> a = b
    [@@ocaml.warning "-39"]
  
    let _ = equal_string_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
