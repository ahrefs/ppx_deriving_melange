Snapshot generated code for a parameterized variant (one printer callback per
type parameter).

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Value of 'a
  >   | Missing
  > [@@deriving show]
  > 
  > type 'a phantom = Id of int [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Value of 'a | Missing [@@deriving show]
  
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
        | Value a0 ->
            Stdlib.Format.fprintf fmt "(@[<2>Input.Value@ ";
            poly_a fmt a0;
            Stdlib.Format.fprintf fmt "@])"
        | Missing -> Stdlib.Format.pp_print_string fmt "Input.Missing"
    [@@ocaml.warning "-39"]
  
    and show : (Stdlib.Format.formatter -> 'a -> unit) -> 'a t -> string =
     fun poly_a -> fun x -> Stdlib.Format.asprintf "%a" (pp poly_a) x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a phantom = Id of int [@@deriving show]
  
  include struct
    let _ = fun (_ : 'a phantom) -> ()
  
    let rec pp_phantom :
        (Stdlib.Format.formatter -> 'a -> unit) ->
        Stdlib.Format.formatter ->
        'a phantom ->
        unit =
     fun poly_a ->
      fun fmt ->
       fun x ->
        match x with
        | Id a0 ->
            Stdlib.Format.fprintf fmt "(@[<2>Input.Id@ ";
            (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt a0;
            Stdlib.Format.fprintf fmt "@])"
    [@@ocaml.warning "-39"]
  
    and show_phantom :
        (Stdlib.Format.formatter -> 'a -> unit) -> 'a phantom -> string =
     fun poly_a -> fun x -> Stdlib.Format.asprintf "%a" (pp_phantom poly_a) x
    [@@ocaml.warning "-39"]
  
    let _ = pp_phantom
    and _ = show_phantom
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a two-parameter record.

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t = {
  >   first : 'a;
  >   second : 'b;
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = { first : 'a; second : 'b }
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec pp :
        (Stdlib.Format.formatter -> 'a -> unit) ->
        (Stdlib.Format.formatter -> 'b -> unit) ->
        Stdlib.Format.formatter ->
        ('a, 'b) t ->
        unit =
     fun poly_a ->
      fun poly_b ->
       fun fmt ->
        fun x ->
         Stdlib.Format.fprintf fmt "@[<2>{ ";
         Stdlib.Format.fprintf fmt "@[%s =@ " "first";
         poly_a fmt x.first;
         Stdlib.Format.fprintf fmt "@]";
         Stdlib.Format.fprintf fmt ";@ ";
         Stdlib.Format.fprintf fmt "@[%s =@ " "second";
         poly_b fmt x.second;
         Stdlib.Format.fprintf fmt "@]";
         Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show :
        (Stdlib.Format.formatter -> 'a -> unit) ->
        (Stdlib.Format.formatter -> 'b -> unit) ->
        ('a, 'b) t ->
        string =
     fun poly_a ->
      fun poly_b -> fun x -> Stdlib.Format.asprintf "%a" ((pp poly_a) poly_b) x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated code for a generic type application.

  $ cat > input.ml <<'EOF'
  > module Box = struct
  >   type 'a t = Box of 'a [@@deriving show]
  > end
  > 
  > module Item = struct
  >   type t =
  >     | A
  >     | B
  >   [@@deriving show]
  > end
  > 
  > type t = Item.t Box.t [@@deriving show]
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
  
  module Item = struct
    type t = A | B [@@deriving show]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec pp : Stdlib.Format.formatter -> t -> unit =
       fun fmt ->
        fun x ->
         match x with
         | A -> Stdlib.Format.pp_print_string fmt "Input.Item.A"
         | B -> Stdlib.Format.pp_print_string fmt "Input.Item.B"
      [@@ocaml.warning "-39"]
  
      and show : t -> string =
       fun x -> match x with A -> "Input.Item.A" | B -> "Input.Item.B"
      [@@ocaml.warning "-39"]
  
      let _ = pp
      and _ = show
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type t = Item.t Box.t [@@deriving show]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt x -> (Box.pp Item.pp) fmt x
    [@@ocaml.warning "-39"]
  
    and show : t -> string = fun x -> Stdlib.Format.asprintf "%a" pp x
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Unsupported functor-applied type paths produce a clear error.

  $ cat > input.ml <<'EOF'
  > module Arg = struct
  >   let offset = 10
  > end
  > 
  > module Make (Input : sig
  >   val offset : int
  > end) = struct
  >   type t = T of int
  > end
  > 
  > type t = Make(Arg).t [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 11, characters 9-20:
  11 | type t = Make(Arg).t [@@deriving show]
                ^^^^^^^^^^^
  Error: deriving.show doesn't support payload type Make(Arg).t
  [1]

Snapshot generated signatures (pp + show; with_path is accepted and ignored).

  $ cat > input.mli <<'EOF'
  > type 'a t = Value of 'a [@@deriving show]
  > 
  > type status = Active [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = Value of 'a [@@deriving show]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val pp :
      (Stdlib.Format.formatter -> 'a -> unit) ->
      Stdlib.Format.formatter ->
      'a t ->
      unit
  
    val show : (Stdlib.Format.formatter -> 'a -> unit) -> 'a t -> string
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = Active [@@deriving show { with_path = false }]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val pp_status : Stdlib.Format.formatter -> status -> unit
    val show_status : status -> string
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
