Snapshot a closed polymorphic variant (constant and payload cases).

  $ cat > input.ml <<'EOF'
  > type t =
  >   [ `All
  >   | `Name of string
  >   | `Count of int
  >   ]
  > [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = [ `All | `Name of string | `Count of int ] [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | `All -> Stdlib.Format.pp_print_string fmt "`All"
       | `Name payload ->
           Stdlib.Format.fprintf fmt "`Name (@[<hov>";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt payload;
           Stdlib.Format.fprintf fmt "@])"
       | `Count payload ->
           Stdlib.Format.fprintf fmt "`Count (@[<hov>";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt payload;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show : t -> string =
     fun x ->
      match x with
      | `All -> "`All"
      | `Name payload ->
          "`Name (" ^ (fun x -> "\"" ^ String.escaped x ^ "\"") payload ^ ")"
      | `Count payload -> "`Count (" ^ string_of_int payload ^ ")"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Inherited polymorphic variant rows are rejected with a clear error (native
ppx_deriving.show supports them; out of scope here, like eq/iter/ord).

  $ cat > input.ml <<'EOF'
  > type base =
  >   [ `A
  >   | `B
  >   ]
  > [@@deriving show]
  > 
  > type t =
  >   [ base
  >   | `C
  >   ]
  > [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 8, characters 4-8:
  8 |   [ base
          ^^^^
  Error: deriving.show doesn't support inherited polymorphic variant rows
  [1]

A [@printer] on a polymorphic variant tag, matching native ppx_deriving.show:
the printer receives the formatter and () for a constant tag or the payload
otherwise, and forces [show] onto the formatter path so both agree.

  $ cat > input.ml <<'EOF'
  > type t =
  >   [ `First [@printer fun fmt () -> Stdlib.Format.pp_print_string fmt "first"]
  >   | `Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
  >   | `Third of string
  >   ]
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t =
    [ `First [@printer fun fmt () -> Stdlib.Format.pp_print_string fmt "first"]
    | `Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
    | `Third of string ]
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       match x with
       | `First ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt () -> Stdlib.Format.pp_print_string fmt "first")
           [@ocaml.warning "-26"])
             fmt ()
       | `Second payload ->
           ((let fprintf = Stdlib.Format.fprintf in
             fun fmt i -> fprintf fmt "second: %d" i)
           [@ocaml.warning "-26"])
             fmt payload
       | `Third payload ->
           Stdlib.Format.fprintf fmt "`Third (@[<hov>";
           (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt payload;
           Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
