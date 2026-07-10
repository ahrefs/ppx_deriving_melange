Snapshot generated code for tuple payloads.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Pair of ('a * string)
  >   | Triple of ('a * int * 'a)
  > [@@deriving fold]
  > 
  > type 'a alias = 'a * string [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Pair of ('a * string) | Triple of ('a * int * 'a)
  [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Pair a0 ->
            (fun acc ->
              fun (a0, a1) ->
               let acc = poly_a acc a0 in
               (fun acc _ -> acc) acc a1)
              acc a0
        | Triple a0 ->
            (fun acc ->
              fun (a0, a1, a2) ->
               let acc = poly_a acc a0 in
               let acc = (fun acc _ -> acc) acc a1 in
               poly_a acc a2)
              acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a alias = 'a * string [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a alias) -> ()
  
    let rec fold_alias : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a alias -> 'b =
     fun poly_a ->
      fun acc ->
       fun (a0, a1) ->
        let acc = poly_a acc a0 in
        (fun acc _ -> acc) acc a1
    [@@ocaml.warning "-39"]
  
    let _ = fold_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
