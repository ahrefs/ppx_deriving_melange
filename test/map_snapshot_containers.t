Snapshot generated code for container payloads.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Items of 'a list
  >   | Maybe of 'a option
  >   | Scores of 'a array
  >   | Parsed of ('a, 'a) result
  >   | Nested of 'a list option
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t =
    | Items of 'a list
    | Maybe of 'a option
    | Scores of 'a array
    | Parsed of ('a, 'a) result
    | Nested of 'a list option
  [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : 'a 'b. ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       match x with
       | Items a0 -> Items ((List.map poly_a) a0)
       | Maybe a0 ->
           Maybe
             ((fun x -> match x with None -> None | Some a -> Some (poly_a a))
                a0)
       | Scores a0 -> Scores ((Array.map poly_a) a0)
       | Parsed a0 ->
           Parsed
             ((fun x ->
                match x with Ok a -> Ok (poly_a a) | Error b -> Error (poly_a b))
                a0)
       | Nested a0 ->
           Nested
             ((fun x ->
                match x with None -> None | Some a -> Some ((List.map poly_a) a))
                a0)
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
