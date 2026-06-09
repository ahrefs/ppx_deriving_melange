Snapshot generated code for standard container payloads.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Strings of string list
  >   | MaybeName of string option
  >   | Scores of int array
  >   | Parsed of (string, int) result
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | Strings of string list
    | MaybeName of string option
    | Scores of int array
    | Parsed of (string, int) result
  [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | Strings a0, Strings b0 ->
           (let rec loop x y =
              match (x, y) with
              | [], [] -> true
              | a :: x, b :: y -> (fun (a : string) b -> a = b) a b && loop x y
              | [], _head :: _tail -> false
              | _head :: _tail, [] -> false
            in
            fun x y -> loop x y)
             a0 b0
       | MaybeName a0, MaybeName b0 ->
           (fun x y ->
             match (x, y) with
             | None, None -> true
             | Some a, Some b -> (fun (a : string) b -> a = b) a b
             | None, Some _value -> false
             | Some _value, None -> false)
             a0 b0
       | Scores a0, Scores b0 ->
           (fun x y ->
             let rec loop i =
               i = Array.length x
               || ((fun (a : int) b -> a = b) x.(i) y.(i) && loop (i + 1))
             in
             Array.length x = Array.length y && loop 0)
             a0 b0
       | Parsed a0, Parsed b0 ->
           (fun x y ->
             match (x, y) with
             | Ok a, Ok b -> (fun (a : string) b -> a = b) a b
             | Error a, Error b -> (fun (a : int) b -> a = b) a b
             | Ok _value, Error _error -> false
             | Error _error, Ok _value -> false)
             a0 b0
       | Strings _0, _ -> false
       | MaybeName _0, _ -> false
       | Scores _0, _ -> false
       | Parsed _0, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
