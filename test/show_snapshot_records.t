Snapshot record printing: the module path lands on the first field only.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   name : string;
  >   count : int;
  > }
  > [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { name : string; count : int } [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "Input.name";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt x.name;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "count";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt x.count;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show : t -> string =
     fun x ->
      ((("{ " ^ "Input.name = " ^ (fun x -> "\"" ^ String.escaped x ^ "\"") x.name)
       ^ "; ")
      ^ "count = " ^ string_of_int x.count)
      ^ " }"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot an inline-record payload (fields are not path-qualified).

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Empty
  >   | Item of {
  >       rank : int;
  >       label : string;
  >     }
  > [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Empty | Item of { rank : int; label : string } [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Empty -> Stdlib.Format.pp_print_string fmt "Input.Empty"
       | Item { rank = a_rank; label = a_label } ->
           Stdlib.Format.fprintf fmt "@[<2>Input.Item {@,";
           Stdlib.Format.fprintf fmt "@[%s =@ " "rank";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a_rank;
           Stdlib.Format.fprintf fmt "@]";
           Stdlib.Format.fprintf fmt ";@ ";
           Stdlib.Format.fprintf fmt "@[%s =@ " "label";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt a_label;
           Stdlib.Format.fprintf fmt "@]";
           Stdlib.Format.fprintf fmt "@]}"
    [@@ocaml.warning "-39"]
  
    and show : t -> string =
     fun x ->
      match x with
      | Empty -> "Input.Empty"
      | Item { rank = a_rank; label = a_label } ->
          ((("Input.Item {" ^ "rank = " ^ string_of_int a_rank) ^ "; ")
          ^ "label = "
          ^ (fun x -> "\"" ^ String.escaped x ^ "\"") a_label)
          ^ "}"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
