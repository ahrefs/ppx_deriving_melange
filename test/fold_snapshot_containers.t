Snapshot generated code for container payloads.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Items of 'a list
  >   | Maybe of 'a option
  >   | Scores of 'a array
  >   | Parsed of ('a, 'a) result
  >   | Nested of 'a list option
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t =
    | Items of 'a list
    | Maybe of 'a option
    | Scores of 'a array
    | Parsed of ('a, 'a) result
    | Nested of 'a list option
  [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        match x with
        | Items a0 -> (List.fold_left poly_a) acc a0
        | Maybe a0 ->
            (fun acc x -> match x with None -> acc | Some a -> poly_a acc a)
              acc a0
        | Scores a0 -> (Array.fold_left poly_a) acc a0
        | Parsed a0 ->
            (fun acc x ->
              match x with Ok a -> poly_a acc a | Error b -> poly_a acc b)
              acc a0
        | Nested a0 ->
            (fun acc x ->
              match x with None -> acc | Some a -> (List.fold_left poly_a) acc a)
              acc a0
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
