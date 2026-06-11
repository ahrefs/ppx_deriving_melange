Snapshot generated code for standard container payloads.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Items of 'a list
  >   | Maybe of 'a option
  >   | Scores of 'a array
  >   | Parsed of ('a, 'a) result
  >   | Nested of 'a list option
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t =
    | Items of 'a list
    | Maybe of 'a option
    | Scores of 'a array
    | Parsed of ('a, 'a) result
    | Nested of 'a list option
  [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Items a0 -> (List.iter poly_a) a0
       | Maybe a0 -> (fun x -> match x with None -> () | Some a -> poly_a a) a0
       | Scores a0 -> (Array.iter poly_a) a0
       | Parsed a0 ->
           (fun x -> match x with Ok a -> poly_a a | Error b -> poly_a b) a0
       | Nested a0 ->
           (fun x -> match x with None -> () | Some a -> (List.iter poly_a) a)
             a0
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
