Snapshot generated code for tuple payload type expressions.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Pair of (int * string)
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Pair of (int * string) [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | Pair a0, Pair b0 ->
           (fun left ->
             fun right ->
              match (left, right) with
              | (left0, left1), (right0, right1) ->
                  (fun (a : int) b -> a = b) left0 right0
                  && (fun (a : string) b -> a = b) left1 right1)
             a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported tuple payload elements produce a clear error.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Pair of (int * (int -> int))
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 20-30:
  2 |   | Pair of (int * (int -> int))
                          ^^^^^^^^^^
  Error: deriving.eq doesn't support payload type int -> int
  [1]
