Snapshot generated code for tuple payloads and a tuple alias.

  $ cat > input.ml <<'EOF'
  > type 'a t =
  >   | Pair of ('a * string)
  >   | Triple of ('a * int * 'a)
  > [@@deriving iter]
  > 
  > type 'a alias = 'a * string [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = Pair of ('a * string) | Triple of ('a * int * 'a)
  [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       match x with
       | Pair a0 ->
           (fun (a0, a1) ->
             poly_a a0;
             (fun _ -> ()) a1)
             a0
       | Triple a0 ->
           (fun (a0, a1, a2) ->
             poly_a a0;
             (fun _ -> ()) a1;
             poly_a a2)
             a0
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
  
  type 'a alias = 'a * string [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a alias) -> ()
  
    let rec iter_alias : ('a -> unit) -> 'a alias -> unit =
     fun poly_a ->
      fun (a0, a1) ->
       poly_a a0;
       (fun _ -> ()) a1
    [@@ocaml.warning "-39"]
  
    let _ = iter_alias
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
