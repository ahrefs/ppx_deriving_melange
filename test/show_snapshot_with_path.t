The default (`with_path = true`) qualifies constructor names with the main
module (capitalized input file basename) plus the submodule path;
`{ with_path = false }` drops the qualification.

  $ cat > input.ml <<'EOF'
  > type t = Red [@@deriving show]
  > type unqualified = Blue [@@deriving show { with_path = false }]
  > 
  > module Nested = struct
  >   type t = Deep [@@deriving show]
  > end
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Red [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x -> match x with Red -> Stdlib.Format.pp_print_string fmt "Input.Red"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> match x with Red -> "Input.Red"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type unqualified = Blue [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : unqualified) -> ()
  
    let rec pp_unqualified : Stdlib.Format.formatter -> unqualified -> unit =
     fun fmt ->
      fun x -> match x with Blue -> Stdlib.Format.pp_print_string fmt "Blue"
    [@@ocaml.warning "-39"]
  
    and show_unqualified : unqualified -> string =
     fun x -> match x with Blue -> "Blue"
    [@@ocaml.warning "-39"]
  
    let _ = pp_unqualified
    and _ = show_unqualified
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  module Nested = struct
    type t = Deep [@@deriving show]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec pp : Stdlib.Format.formatter -> t -> unit =
       fun fmt ->
        fun x ->
         match x with
         | Deep -> Stdlib.Format.pp_print_string fmt "Input.Nested.Deep"
      [@@ocaml.warning "-39"]
  
      and show : t -> string = fun x -> match x with Deep -> "Input.Nested.Deep"
      [@@ocaml.warning "-39"]
  
      let _ = pp
      and _ = show
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end

A re-exported definition prints the manifest's module path, and a manifest
referring to a local name drops the path entirely (native parity).

  $ cat > input.ml <<'EOF'
  > module M = struct
  >   type s = A | B [@@deriving show]
  > end
  > 
  > type u = M.s = A | B [@@deriving show]
  > 
  > type t = Red [@@deriving show { with_path = false }]
  > type v = t = Red [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module M = struct
    type s = A | B [@@deriving show]
  
    include struct
      let _ = fun (_ : s) -> ()
  
      let rec pp_s : Stdlib.Format.formatter -> s -> unit =
       fun fmt ->
        fun x ->
         match x with
         | A -> Stdlib.Format.pp_print_string fmt "Input.M.A"
         | B -> Stdlib.Format.pp_print_string fmt "Input.M.B"
      [@@ocaml.warning "-39"]
  
      and show_s : s -> string =
       fun x -> match x with A -> "Input.M.A" | B -> "Input.M.B"
      [@@ocaml.warning "-39"]
  
      let _ = pp_s
      and _ = show_s
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type u = M.s = A | B [@@deriving show]
  
  include struct
    let _ = fun (_ : u) -> ()
  
    let rec pp_u : Stdlib.Format.formatter -> u -> unit =
     fun fmt ->
      fun x ->
       match x with
       | A -> Stdlib.Format.pp_print_string fmt "M.A"
       | B -> Stdlib.Format.pp_print_string fmt "M.B"
    [@@ocaml.warning "-39"]
  
    and show_u : u -> string = fun x -> match x with A -> "M.A" | B -> "M.B"
    [@@ocaml.warning "-39"]
  
    let _ = pp_u
    and _ = show_u
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type t = Red [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x -> match x with Red -> Stdlib.Format.pp_print_string fmt "Red"
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> match x with Red -> "Red"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type v = t = Red [@@deriving show]
  
  include struct
    let _ = fun (_ : v) -> ()
  
    let rec pp_v : Stdlib.Format.formatter -> v -> unit =
     fun fmt ->
      fun x -> match x with Red -> Stdlib.Format.pp_print_string fmt "Red"
    [@@ocaml.warning "-39"]
  
    and show_v : v -> string = fun x -> match x with Red -> "Red"
    [@@ocaml.warning "-39"]
  
    let _ = pp_v
    and _ = show_v
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
