Snapshot generated code for a simple variant with a payload.

  $ cat > input.ml <<'EOF'
  > type t =
  >   | Latest
  >   | Date of string
  > [@@deriving eq]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = Latest | Date of string [@@deriving eq]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let rec equal : t -> t -> bool =
     fun a ->
      fun b ->
       match (a, b) with
       | Latest, Latest -> true
       | Date a0, Date b0 -> (fun (a : string) b -> a = b) a0 b0
       | Latest, _ -> false
       | Date _0, _ -> false
    [@@ocaml.warning "-39"]
  
    let _ = equal
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
