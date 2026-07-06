Snapshot the container printers (list/option/array/result).

  $ cat > input.ml <<'EOF'
  > type t = {
  >   items : int list;
  >   maybe : int option;
  >   scores : int array;
  >   outcome : (int, string) result;
  > }
  > [@@deriving show { with_path = false }]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = {
    items : int list;
    maybe : int option;
    scores : int array;
    outcome : (int, string) result;
  }
  [@@deriving show { with_path = false }]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec pp : Stdlib.Format.formatter -> t -> unit =
     fun fmt ->
      fun x ->
       Stdlib.Format.fprintf fmt "@[<2>{ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "items";
       (fun fmt x ->
         Stdlib.Format.fprintf fmt "@[<2>[";
         ignore
           (List.fold_left
              (fun sep x ->
                if sep then Stdlib.Format.fprintf fmt ";@ ";
                (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt x;
                true)
              false x);
         Stdlib.Format.fprintf fmt "@,]@]")
         fmt x.items;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "maybe";
       (fun fmt x ->
         match x with
         | None -> Stdlib.Format.pp_print_string fmt "None"
         | Some value ->
             Stdlib.Format.pp_print_string fmt "(Some ";
             (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt value;
             Stdlib.Format.pp_print_string fmt ")")
         fmt x.maybe;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "scores";
       (fun fmt x ->
         Stdlib.Format.fprintf fmt "@[<2>[|";
         ignore
           (Array.fold_left
              (fun sep x ->
                if sep then Stdlib.Format.fprintf fmt ";@ ";
                (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt x;
                true)
              false x);
         Stdlib.Format.fprintf fmt "@,|]@]")
         fmt x.scores;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt ";@ ";
       Stdlib.Format.fprintf fmt "@[%s =@ " "outcome";
       (fun fmt x ->
         match x with
         | Ok value ->
             Stdlib.Format.pp_print_string fmt "(Ok ";
             (fun fmt x -> Stdlib.Format.fprintf fmt "%d" x) fmt value;
             Stdlib.Format.pp_print_string fmt ")"
         | Error error ->
             Stdlib.Format.pp_print_string fmt "(Error ";
             (fun fmt x -> Stdlib.Format.fprintf fmt "%S" x) fmt error;
             Stdlib.Format.pp_print_string fmt ")")
         fmt x.outcome;
       Stdlib.Format.fprintf fmt "@]";
       Stdlib.Format.fprintf fmt "@ }@]"
    [@@ocaml.warning "-39"]
  
    and show : t -> string =
     fun x ->
      ((((((("{ " ^ "items = "
            ^ (fun x -> "[" ^ String.concat "; " (List.map string_of_int x) ^ "]")
                x.items)
           ^ "; ")
          ^ "maybe = "
          ^ (fun x ->
              match x with
              | None -> "None"
              | Some value -> "(Some " ^ string_of_int value ^ ")")
              x.maybe)
         ^ "; ")
        ^ "scores = "
        ^ (fun x ->
            "[|"
            ^ String.concat "; " (Array.to_list (Array.map string_of_int x))
            ^ "|]")
            x.scores)
       ^ "; ")
      ^ "outcome = "
      ^ (fun x ->
          match x with
          | Ok value -> "(Ok " ^ string_of_int value ^ ")"
          | Error error ->
              "(Error " ^ (fun x -> "\"" ^ String.escaped x ^ "\"") error ^ ")")
          x.outcome)
      ^ " }"
    [@@ocaml.warning "-39"]
  
    let _ = pp
    and _ = show
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot container aliases of custom types.

  $ cat > input.ml <<'EOF'
  > module Item = struct
  >   type t = A [@@deriving show]
  > end
  > 
  > type items = Item.t list [@@deriving show]
  > type maybe_item = Item.t option [@@deriving show]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  module Item = struct
    type t = A [@@deriving show]
  
    include struct
      let _ = fun (_ : t) -> ()
  
      let rec pp : Stdlib.Format.formatter -> t -> unit =
       fun fmt ->
        fun x ->
         match x with A -> Stdlib.Format.pp_print_string fmt "Input.Item.A"
      [@@ocaml.warning "-39"]
  
      and show : t -> string = fun x -> match x with A -> "Input.Item.A"
      [@@ocaml.warning "-39"]
  
      let _ = pp
      and _ = show
    end [@@ocaml.doc "@inline"] [@@merlin.hide]
  end
  
  type items = Item.t list [@@deriving show]
  
  include struct
    let _ = fun (_ : items) -> ()
  
    let rec pp_items : Stdlib.Format.formatter -> items -> unit =
     fun fmt x ->
      Stdlib.Format.fprintf fmt "@[<2>[";
      ignore
        (List.fold_left
           (fun sep x ->
             if sep then Stdlib.Format.fprintf fmt ";@ ";
             Item.pp fmt x;
             true)
           false x);
      Stdlib.Format.fprintf fmt "@,]@]"
    [@@ocaml.warning "-39"]
  
    and show_items : items -> string =
     fun x -> "[" ^ String.concat "; " (List.map Item.show x) ^ "]"
    [@@ocaml.warning "-39"]
  
    let _ = pp_items
    and _ = show_items
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type maybe_item = Item.t option [@@deriving show]
  
  include struct
    let _ = fun (_ : maybe_item) -> ()
  
    let rec pp_maybe_item : Stdlib.Format.formatter -> maybe_item -> unit =
     fun fmt x ->
      match x with
      | None -> Stdlib.Format.pp_print_string fmt "None"
      | Some value ->
          Stdlib.Format.pp_print_string fmt "(Some ";
          Item.pp fmt value;
          Stdlib.Format.pp_print_string fmt ")"
    [@@ocaml.warning "-39"]
  
    and show_maybe_item : maybe_item -> string =
     fun x ->
      match x with
      | None -> "None"
      | Some value -> "(Some " ^ Item.show value ^ ")"
    [@@ocaml.warning "-39"]
  
    let _ = pp_maybe_item
    and _ = show_maybe_item
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
