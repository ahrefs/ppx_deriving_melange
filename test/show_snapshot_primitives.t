Snapshot the primitive printers (typed format strings; bytes goes through
Bytes.to_string; unit prints ()).

  $ cat > input.ml <<'EOF'
  > type t = {
  >   s : string;
  >   n : int;
  >   b : bool;
  >   f : float;
  >   c : char;
  >   raw : bytes;
  >   i32 : int32;
  >   i64 : int64;
  >   boxed32 : Int32.t;
  >   boxed64 : Int64.t;
  >   nothing : unit;
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = {
    s : string;
    n : int;
    b : bool;
    f : float;
    c : char;
    raw : bytes;
    i32 : int32;
    i64 : int64;
    boxed32 : Int32.t;
    boxed64 : Int64.t;
    nothing : unit;
  }
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "s";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt x.s;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "n";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt x.n;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "b";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%B" x) fmt x.b;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "f";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%F" x) fmt x.f;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "c";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%C" x) fmt x.c;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "raw";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%S" (Bytes.to_string x)) fmt x.raw;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "i32";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%ldl" x) fmt x.i32;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "i64";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%LdL" x) fmt x.i64;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "boxed32";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%ldl" x) fmt x.boxed32;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "boxed64";
       (fun fmt x -> Stdlib.Format.fprintf fmt "%LdL" x) fmt x.boxed64;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "nothing";
       (fun fmt () -> Stdlib.Format.pp_print_string fmt "()") fmt x.nothing;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
