Custom printers via [@printer]; the printer body can use the bare `fprintf`
idiom from native ppx_deriving.show.

  $ cat > input.ml <<'EOF'
  > type t = Named of (string[@printer fun fmt -> fprintf fmt "name=%s"]) [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Named of (string[@printer fun fmt -> fprintf fmt "name=%s"])
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | Named a0 ->
           Stdlib.Format.fprintf fmt "(@[<2>Named@ ";
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt -> fprintf fmt "name=%s")
           [@ocaml.warning "-26"])
             fmt a0;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

The namespaced form [@deriving.show.printer] is accepted too.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   at : (float[@deriving.show.printer fun fmt x -> Stdlib.Format.fprintf fmt "%.2f" x]);
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = {
    at :
      (float
      [@deriving.show.printer fun fmt x -> Stdlib.Format.fprintf fmt "%.2f" x]);
  }
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "at";
       ((let fprintf = Stdlib.Format.fprintf in
         fun fmt x -> Stdlib.Format.fprintf fmt "%.2f" x)
       [@ocaml.warning "-26"])
         fmt x.at;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

[@opaque] skips traversal and prints <opaque>; arrow types print <fun>.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   secret : (string[@opaque]);
  >   callback : int -> unit;
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { secret : (string[@opaque]); callback : int -> unit }
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "secret";
       (fun fmt _value -> Stdlib.Format.pp_print_string fmt "<opaque>")
         fmt x.secret;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "callback";
       (fun fmt _function_value -> Stdlib.Format.pp_print_string fmt "<fun>")
         fmt x.callback;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show : t -> string =
     fun x ->
      ((("{ " ^ "secret = " ^ (fun _value -> "<opaque>") x.secret) ^ "; ")
      ^ "callback = "
      ^ (fun _function_value -> "<fun>") x.callback)
      ^ " }"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Constructor-level [@printer] (native parity): the printer receives fmt and the
payload packed as one value (unit, the single payload, or a tuple); for
inline-record payloads it receives each field as a separate argument.

  $ cat > input.ml <<'EOF2'
  > type t =
  >   | First [@printer fun fmt _ -> Format.pp_print_string fmt "first"]
  >   | Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
  >   | Third
  >   | Fourth of int * int [@printer fun fmt (a, b) -> fprintf fmt "fourth: %d %d" a b]
  >   | Fifth of { x : int; y : string } [@printer fun fmt x y -> fprintf fmt "fifth: %d %s" x y]
  > [@@deriving show { with_path = false }]
  > EOF2
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    | First [@printer fun fmt _ -> Format.pp_print_string fmt "first"]
    | Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
    | Third
    | Fourth of int * int
        [@printer fun fmt (a, b) -> fprintf fmt "fourth: %d %d" a b]
    | Fifth of { x : int; y : string }
        [@printer fun fmt x y -> fprintf fmt "fifth: %d %s" x y]
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | First ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt _ -> Format.pp_print_string fmt "first")
           [@ocaml.warning "-26"])
             fmt ()
       | Second a0 ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt i -> fprintf fmt "second: %d" i)
           [@ocaml.warning "-26"])
             fmt a0
       | Third -> Stdlib.Format.pp_print_string fmt "Third"
       | Fourth (a0, a1) ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt (a, b) -> fprintf fmt "fourth: %d %d" a b)
           [@ocaml.warning "-26"])
             fmt (a0, a1)
       | Fifth { x = a_x; y = a_y } ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt x y -> fprintf fmt "fifth: %d %s" x y)
           [@ocaml.warning "-26"])
             fmt a_x a_y
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
