Snapshot generated code for a parameterized record.

  $ cat > input.ml <<'EOF'
  > type 'a t = {
  >   items : 'a list;
  >   name : string;
  >   value : 'a;
  > }
  > [@@deriving map]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = { items : 'a list; name : string; value : 'a } [@@deriving map]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec map : ('a -> 'b) -> 'a t -> 'b t =
     fun poly_a ->
      fun x ->
       {
         items = (List.map poly_a) x.items;
         name = (fun x -> x) x.name;
         value = poly_a x.value;
       }
    [@@ocaml.warning "-39"]
  
    let _ = map
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
