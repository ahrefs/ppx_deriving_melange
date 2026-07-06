Snapshot generated code for tuple payloads.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Pair of ('a * string)
  >   | Triple of ('a * int * 'a)
  > [@@deriving map]
  > 
  > type 'a alias = 'a * string [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Pair of ('a * string) | Triple of ('a * int * 'a) [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       match x with
       | Pair a0 -> Pair ((fun (a0, a1) -> (poly_a a0, (fun x -> x) a1)) a0)
       | Triple a0 ->
           Triple
             ((fun (a0, a1, a2) -> (poly_a a0, (fun x -> x) a1, poly_a a2)) a0)
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a alias = 'a * string [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a alias) -> ()
  
    let rec map_alias : 'a 'b. ('a -> 'b) -> 'a alias -> 'b alias =
     fun poly_a -> fun (a0, a1) -> (poly_a a0, (fun x -> x) a1)
    [@@ocaml.warning "-39"]
  
    let _ = map_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
