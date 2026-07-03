Snapshot a tuple alias and a nested tuple payload.

  $ cat > input.ml <<'EOF'
  > type t = int * string [@@deriving show]
  > 
  > type nested = Pair of (int * (string * bool)) [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = int * string [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun (a0, a1) ->
       Stdlib.Format.fprintf fmt "(@[";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
       Stdlib.Format.fprintf fmt ",@ ";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt a1;
       Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type nested = Pair of (int * (string * bool))
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : nested) -> ()
  
    let rec pp_nested : Stdlib.Format.formatter -> nested -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Pair a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Pair@ ";
           (fun fmt ->
             fun (a0, a1) ->
              Stdlib.Format.fprintf fmt "(@[";
              (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
              Stdlib.Format.fprintf fmt ",@ ";
              (fun fmt ->
                fun (a0, a1) ->
                 Stdlib.Format.fprintf fmt "(@[";
                 (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt a0;
                 Stdlib.Format.fprintf fmt ",@ ";
                 (fun fmt x -> Stdlib.Format.fprintf fmt "%B" x) fmt a1;
                 Stdlib.Format.fprintf fmt "@])")
                fmt a1;
              Stdlib.Format.fprintf fmt "@])")
             fmt a0;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show_nested : nested -> string =
     fun x -> Stdlib.Format.asprintf "%a" pp_nested x
    [@@ocaml.warning "-39"]
  
    let _ = pp_nested
    and _ = show_nested
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
