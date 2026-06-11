Snapshot generated code for a parameterized record type.

  $ cat > input.ml <<'EOF'
  > type 'a t = {
  >   items : 'a list;
  >   name : string;
  >   value : 'a;
  > }
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = { items : 'a list; name : string; value : 'a } [@@deriving iter]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec iter : ('a -> unit) -> 'a t -> unit =
     fun poly_a ->
      fun x ->
       (List.iter poly_a) x.items;
       (fun _ -> ()) x.name;
       poly_a x.value
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
