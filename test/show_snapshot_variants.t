Snapshot generated names for `t` and non-`t` types, and the three payload
shapes (constant, single payload, n-ary payload).

  $ cat > input.ml <<'EOF'
  > type t = Red | Green | Blue [@@deriving show]
  > type status = Zero | One of int | Pair of int * string [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Red | Green | Blue [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Red -> Stdlib.Format.pp_print_string fmt "Input.Red"
       | Green -> Stdlib.Format.pp_print_string fmt "Input.Green"
       | Blue -> Stdlib.Format.pp_print_string fmt "Input.Blue"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Zero | One of int | Pair of int * string [@@deriving show]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let rec pp_status : Stdlib.Format.formatter -> status -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Zero -> Stdlib.Format.pp_print_string fmt "Input.Zero"
       | One a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Input.One@ ";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
           Stdlib.Format.fprintf fmt "@])"
       | Pair (a0, a1) ->
           Stdlib.Format.fprintf fmt "(@[<2>Input.Pair (@,";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
           Stdlib.Format.fprintf fmt ",@ ";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt a1;
           Stdlib.Format.fprintf fmt "@,))@]"
    [@@ocaml.warning "-39"]
  
    and show_status : status -> string =
     fun x -> Stdlib.Format.asprintf "%a" pp_status x
    [@@ocaml.warning "-39"]
  
    let _ = pp_status
    and _ = show_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot a single-constructor type.

  $ cat > input.ml <<'EOF'
  > type wrap = Wrap of int [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type wrap = Wrap of int [@@deriving show]
  
  include struct
    let _ = fun (_ : wrap) -> ()
  
    let rec pp_wrap : Stdlib.Format.formatter -> wrap -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Wrap a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Input.Wrap@ ";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show_wrap : wrap -> string =
     fun x -> Stdlib.Format.asprintf "%a" pp_wrap x
    [@@ocaml.warning "-39"]
  
    let _ = pp_wrap
    and _ = show_wrap
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
