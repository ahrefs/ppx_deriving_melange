The [%show: ...] expression extension builds the string directly whenever the
type allows it, exactly like the generated `show` function — no Format in the
expansion.

  $ cat > input.ml <<'EOF'
  > module Foo = struct
  >   type t = { x : int } [@@deriving show]
  > end
  > 
  > let primitive = [%show: int]
  > let composed = [%show: (int * string) option]
  > let container = [%show: int list]
  > let referenced = [%show: Foo.t]
  > let polyvariant = [%show: [ `A | `B of int ]]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Foo = struct
    type t = { x : int } [@@deriving show]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec pp : Stdlib.Format.formatter -> t -> unit =
       fun fmt ->
        fun x ->
         Stdlib.Format.fprintf fmt "@[<2>{ ";
         Stdlib.Format.fprintf fmt "@[%s =@ " "Input.Foo.x";
         (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt x.x;
         Stdlib.Format.fprintf fmt "@]";
         Stdlib.Format.fprintf fmt "@ }@]"
      [@@ocaml.warning "-39"]
  
      and show : t -> string =
       fun x -> ("{ " ^ "Input.Foo.x = " ^ string_of_int x.x) ^ " }"
      [@@ocaml.warning "-39"]
  
      let _ = pp
      and _ = show
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  let primitive = string_of_int
  
  let composed x =
    match x with
    | None -> "None"
    | Some value ->
        "(Some "
        ^ (fun (a0, a1) ->
            ((("(" ^ string_of_int a0) ^ ", ")
            ^ (fun x -> "\"" ^ String.escaped x ^ "\"") a1)
            ^ ")")
            value
        ^ ")"
  
  let container x = "[" ^ String.concat "; " (List.map string_of_int x) ^ "]"
  let referenced = Foo.show
  
  let polyvariant x =
    match x with `A -> "`A" | `B payload -> "`B (" ^ string_of_int payload ^ ")"

Result types work inline too (native tests this shape explicitly).

  $ cat > input.ml <<'EOF'
  > let outcome = [%show: (int, bool) result]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let outcome x =
    match x with
    | Ok value -> "(Ok " ^ string_of_int value ^ ")"
    | Error error -> "(Error " ^ string_of_bool error ^ ")"

An application of a parameterized type needs a formatter, so the extension
falls back to `Stdlib.Format.asprintf "%a"` over the composed `pp` — the same
fallback the generated `show` uses.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving show]
  > end
  > 
  > let fallback = [%show: int Box.t]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Box = struct
    type 'a t = Box of 'a [@@deriving show]
  
    include struct
      let _ = fun (_ : 'a t) -> ()
  
      let rec pp :
          (Stdlib.Format.formatter -> 'a -> unit) ->
          Stdlib.Format.formatter ->
          'a t ->
          unit =
       fun poly_a ->
        fun fmt ->
         fun x ->
          match x with
          | Box a0 ->
              Stdlib.Format.fprintf fmt "(@[<2>Input.Box.Box@ ";
              poly_a fmt a0;
              Stdlib.Format.fprintf fmt "@])"
      [@@ocaml.warning "-39"]
  
      and show : (Stdlib.Format.formatter -> 'a -> unit) -> 'a t -> string =
       fun poly_a -> fun x -> Stdlib.Format.asprintf "%a" (pp poly_a) x
      [@@ocaml.warning "-39"]
  
      let _ = pp
      and _ = show
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  let fallback x =
    Stdlib.Format.asprintf "%a"
      (Box.pp (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x))
      x

The namespaced [%derive.show: ...] form expands identically.

  $ cat > input.ml <<'EOF'
  > let prefixed = [%derive.show: string option]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let prefixed x =
    match x with
    | None -> "None"
    | Some value ->
        "(Some " ^ (fun x -> "\"" ^ String.escaped x ^ "\"") value ^ ")"

Free type variables are rejected.

  $ cat > input.ml <<'EOF'
  > let unbound = [%show: 'a list]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 22-29:
  1 | let unbound = [%show: 'a list]
                            ^^^^^^^
  Error: deriving.show doesn't support free type variables ('a) in [%show: ...]
  [1]

[%pp: ...] is deliberately not registered (native has no inline formatter
extension), so it passes through unexpanded.

  $ cat > input.ml <<'EOF'
  > let not_ours = [%pp: int]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  let not_ours = [%pp: int]
