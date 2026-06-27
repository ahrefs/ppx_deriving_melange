Snapshot generated code for a custom comparison via [@compare ...].

  $ cat > input.ml <<'EOF'
  > type t = ByLength of (string[@compare fun a b -> Stdlib.compare (String.length a) (String.length b)]) [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | ByLength of
        (string
        [@compare fun a b -> Stdlib.compare (String.length a) (String.length b)])
  [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match (a, b) with
       | ByLength a0, ByLength b0 ->
           (fun a b -> Stdlib.compare (String.length a) (String.length b)) a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

The namespaced [@deriving.ord.compare ...] form is also accepted.

  $ cat > input.ml <<'EOF'
  > type t = ByLength of (string[@deriving.ord.compare fun a b -> Stdlib.compare (String.length a) (String.length b)]) [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | ByLength of
        (string
        [@deriving.ord.compare
          fun a b -> Stdlib.compare (String.length a) (String.length b)])
  [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match (a, b) with
       | ByLength a0, ByLength b0 ->
           (fun a b -> Stdlib.compare (String.length a) (String.length b)) a0 b0
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A custom comparison on a record field.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   urls : string list; [@compare fun a b -> Stdlib.compare (List.sort String.compare a) (List.sort String.compare b)]
  >   name : string;
  > }
  > [@@deriving ord]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = {
    urls : string list;
        [@compare
          fun a b ->
            Stdlib.compare
              (List.sort String.compare a)
              (List.sort String.compare b)]
    name : string;
  }
  [@@deriving ord]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec compare : t -> t -> int =
     fun a ->
      fun b ->
       match
         (fun a b ->
           Stdlib.compare
             (List.sort String.compare a)
             (List.sort String.compare b))
           a.urls b.urls
       with
       | 0 -> (fun (a : string) b -> Stdlib.compare a b) a.name b.name
       | result -> result
    [@@ocaml.warning "-39"]
  
    let _ = compare
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
