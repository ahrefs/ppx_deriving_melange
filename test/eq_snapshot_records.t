Snapshot generated code for a record field custom equality attribute.

  $ cat > input.ml <<'EOF'
  > let equal_unordered_string_list a b = List.sort String.compare a = List.sort String.compare b
  > 
  > type t = {
  >   urls_groups : string list; [@equal equal_unordered_string_list]
  >   name : string;
  > }
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let equal_unordered_string_list a b =
    List.sort String.compare a = List.sort String.compare b
  
  type t = {
    urls_groups : string list; [@equal equal_unordered_string_list]
    name : string;
  }
  [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun lhs ->
      fun rhs ->
       equal_unordered_string_list lhs.urls_groups rhs.urls_groups
       && (fun (a : string) b -> a = b) lhs.name rhs.name
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for record payload constructors.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Item of { name : string }
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Item of { name : string } [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | Item { name = a_name }, Item { name = b_name } ->
           (fun (a : string) b -> a = b) a_name b_name
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported record payload constructor fields produce a clear error.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Item of { callback : int -> int }
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 25-35:
  2 |   | Item of { callback : int -> int }
                               ^^^^^^^^^^
  Error: deriving.eq doesn't support payload type int -> int
  [1]

Snapshot generated code for a record.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   name : string;
  >   count : int;
  > }
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { name : string; count : int } [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun lhs ->
      fun rhs ->
       (fun (a : string) b -> a = b) lhs.name rhs.name
       && (fun (a : int) b -> a = b) lhs.count rhs.count
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
