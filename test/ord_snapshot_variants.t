Snapshot generated names and constructor ordering for `t` and non-`t` types.

  $ cat > input.ml <<'EOF'
  > type t = Red | Green | Blue [@@deriving ord]
  > type status = Active | Inactive [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Red | Green | Blue [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       let to_int value = match value with Red -> 0 | Green -> 1 | Blue -> 2 in
       match (a, b) with
       | Red, Red -> 0
       | Green, Green -> 0
       | Blue, Blue -> 0
       | Red, _ -> Stdlib.compare (to_int a) (to_int b)
       | Green, _ -> Stdlib.compare (to_int a) (to_int b)
       | Blue, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active | Inactive [@@deriving ord]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec compare_status : status -> status -> int =
     fun a ->
      fun b ->
       let to_int value = match value with Active -> 0 | Inactive -> 1 in
       match (a, b) with
       | Active, Active -> 0
       | Inactive, Inactive -> 0
       | Active, _ -> Stdlib.compare (to_int a) (to_int b)
       | Inactive, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot lexicographic payload tie-break and a single-constructor type (no
cross-constructor fallback cases needed).

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Pair of int * string
  >   | Single of int
  > [@@deriving ord]
  > 
  > type wrap = Wrap of int [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Pair of int * string | Single of int [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       let to_int value = match value with Pair _ -> 0 | Single _ -> 1 in
       match (a, b) with
       | Pair (a0, a1), Pair (b0, b1) -> (
           match (fun (a : int) b -> Stdlib.compare a b) a0 b0 with
           | 0 -> (fun (a : string) b -> Stdlib.compare a b) a1 b1
           | result -> result)
       | Single a0, Single b0 -> (fun (a : int) b -> Stdlib.compare a b) a0 b0
       | Pair (_0, _1), _ -> Stdlib.compare (to_int a) (to_int b)
       | Single _0, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type wrap = Wrap of int [@@deriving ord]
  
  include struct
    let _ = fun (_ : wrap) -> ()
  
    let rec compare_wrap : wrap -> wrap -> int =
     fun a ->
      fun b ->
       match (a, b) with
       | Wrap a0, Wrap b0 -> (fun (a : int) b -> Stdlib.compare a b) a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = compare_wrap
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
