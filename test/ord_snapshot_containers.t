Snapshot generated code for standard container payloads.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Items of int list
  >   | Maybe of int option
  >   | Scores of int array
  >   | Parsed of (int, string) result
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | Items of int list
    | Maybe of int option
    | Scores of int array
    | Parsed of (int, string) result
  [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       let to_int value =
         match value with
         | Items _ -> 0
         | Maybe _ -> 1
         | Scores _ -> 2
         | Parsed _ -> 3
       in
       match (a, b) with
       | Items a0, Items b0 ->
           (let rec loop x y =
              match (x, y) with
              | [], [] -> 0
              | [], _head :: _tail -> -1
              | _head :: _tail, [] -> 1
              | a :: x, b :: y -> (
                  match (fun (a : int) b -> Stdlib.compare a b) a b with
                  | 0 -> loop x y
                  | result -> result)
            in
            fun x y -> loop x y)
             a0 b0
       | Maybe a0, Maybe b0 ->
           (fun x y ->
             match (x, y) with
             | None, None -> 0
             | Some a, Some b -> (fun (a : int) b -> Stdlib.compare a b) a b
             | None, Some _value -> -1
             | Some _value, None -> 1)
             a0 b0
       | Scores a0, Scores b0 ->
           (fun x y ->
             let rec loop i =
               if i = Array.length x then 0
               else
                 match (fun (a : int) b -> Stdlib.compare a b) x.(i) y.(i) with
                 | 0 -> loop (i + 1)
                 | result -> result
             in
             match Stdlib.compare (Array.length x) (Array.length y) with
             | 0 -> loop 0
             | result -> result)
             a0 b0
       | Parsed a0, Parsed b0 ->
           (fun x y ->
             match (x, y) with
             | Error a, Error b -> (fun (a : string) b -> Stdlib.compare a b) a b
             | Ok a, Ok b -> (fun (a : int) b -> Stdlib.compare a b) a b
             | Ok _value, Error _error -> -1
             | Error _error, Ok _value -> 1)
             a0 b0
       | Items _0, _ -> Stdlib.compare (to_int a) (to_int b)
       | Maybe _0, _ -> Stdlib.compare (to_int a) (to_int b)
       | Scores _0, _ -> Stdlib.compare (to_int a) (to_int b)
       | Parsed _0, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
