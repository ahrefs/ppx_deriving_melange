Snapshot generated code for a two-parameter record: each field is visited by
the callback matching its own type parameter, in declaration order (native
ppx_deriving regression test for issue #82).

  $ cat > input.ml <<'EOF'
  > type ('a, 'b) t = {
  >   first : 'a;
  >   second : 'b;
  > }
  > [@@deriving iter]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type ('a, 'b) t = { first : 'a; second : 'b } [@@deriving iter]
  
  include struct
    let _ = fun (_ : ('a, 'b) t) -> ()
  
    let rec iter : ('a -> unit) -> ('b -> unit) -> ('a, 'b) t -> unit =
     fun poly_a ->
      fun poly_b ->
       fun x ->
        poly_a x.first;
        poly_b x.second
    [@@ocaml.warning "-39"]
  
    let _ = iter
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

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
