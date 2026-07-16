Snapshot generated code for parameterized records. Type parameters flow
through with no extra machinery, and arguments follow field declaration order.

  $ cat > input.ml <<'EOF'
  > type 'a t = {
  >   value : 'a;
  >   children : 'a t list;
  > }
  > [@@deriving make]
  > 
  > type ('k, 'v) entry = {
  >   key : 'k;
  >   value : 'v;
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = { value : 'a; children : 'a t list } [@@deriving make]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
    let make ~value = fun ?(children = []) -> fun () -> { value; children }
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type ('k, 'v) entry = { key : 'k; value : 'v } [@@deriving make]
  
  include struct
    let _ = fun (_ : ('k, 'v) entry) -> ()
    let make_entry ~key = fun ~value -> { key; value }
    let _ = make_entry
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

Snapshot generated signatures.

  $ cat > input.mli <<'EOF'
  > type 'a t = {
  >   value : 'a;
  >   children : 'a t list;
  > }
  > [@@deriving make]
  > 
  > type status = {
  >   id : int;
  >   note : string option;
  >   label : string; [@main]
  > }
  > [@@deriving make]
  > 
  > type pair = {
  >   first : int;
  >   second : string;
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -intf input.mli -o output.mli
  $ ocamlformat --enable-outside-detected-project --intf output.mli
  type 'a t = { value : 'a; children : 'a t list } [@@deriving make]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val make : value:'a -> ?children:'a t list -> unit -> 'a t
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type status = { id : int; note : string option; label : string [@main] }
  [@@deriving make]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val make_status : id:int -> ?note:string -> string -> status
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type pair = { first : int; second : string } [@@deriving make]
  
  include sig
    [@@@ocaml.warning "-32"]
  
    val make_pair : first:int -> second:string -> pair
  end
  [@@ocaml.doc "@inline"] [@@merlin.hide]
