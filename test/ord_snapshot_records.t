Snapshot generated code for a record type (lexicographic over fields).

  $ cat > input.ml <<'EOF'
  > type t = {
  >   name : string;
  >   count : int;
  > }
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { name : string; count : int } [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match (fun (a : string) b -> Stdlib.compare a b) a.name b.name with
       | 0 -> (fun (a : int) b -> Stdlib.compare a b) a.count b.count
       | result -> result
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a record payload constructor.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Empty
  >   | Item of {
  >       rank : int;
  >       label : string;
  >     }
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Empty | Item of { rank : int; label : string } [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       let to_int value = match value with Empty -> 0 | Item _ -> 1 in
       match (a, b) with
       | Empty, Empty -> 0
       | ( Item { rank = a_rank; label = a_label },
           Item { rank = b_rank; label = b_label } ) -> (
           match (fun (a : int) b -> Stdlib.compare a b) a_rank b_rank with
           | 0 -> (fun (a : string) b -> Stdlib.compare a b) a_label b_label
           | result -> result)
       | Empty, _ -> Stdlib.compare (to_int a) (to_int b)
       | Item _, _ -> Stdlib.compare (to_int a) (to_int b)
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
