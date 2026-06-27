Snapshot generated code for tuple payloads and a tuple alias.

  $ cat > input.ml <<'EOF'
  > type t = Pair of (int * string) [@@deriving ord]
  > 
  > type alias = int * string [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Pair of (int * string) [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match (a, b) with
       | Pair a0, Pair b0 ->
           (fun (a0, a1) ->
             fun (b0, b1) ->
              match (fun (a : int) b -> Stdlib.compare a b) a0 b0 with
              | 0 -> (fun (a : string) b -> Stdlib.compare a b) a1 b1
              | result -> result)
             a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type alias = int * string [@@deriving ord]
  
  include struct
    let _ = fun (_ : alias) -> ()
  
    let rec compare_alias : alias -> alias -> int =
     fun (a0, a1) ->
      fun (b0, b1) ->
       match (fun (a : int) b -> Stdlib.compare a b) a0 b0 with
       | 0 -> (fun (a : string) b -> Stdlib.compare a b) a1 b1
       | result -> result
    [@@ocaml.warning "-39"]
  
    let _ = compare_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
