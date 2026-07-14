Snapshot generated code for a parameterized record.

  $ cat > input.ml <<'EOF'
  > type 'a t = {
  >   items : 'a list;
  >   name : string;
  >   value : 'a;
  > }
  > [@@deriving fold]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type 'a t = { items : 'a list; name : string; value : 'a } [@@deriving fold]
  
  include struct
    let _ = fun (_ : 'a t) -> ()
  
    let rec fold : 'a 'b. ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b =
     fun poly_a ->
      fun acc ->
       fun x ->
        let acc = (List.fold_left poly_a) acc x.items in
        let acc = (fun acc _ -> acc) acc x.name in
        poly_a acc x.value
    [@@ocaml.warning "-39"]
  
    let _ = fold
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
