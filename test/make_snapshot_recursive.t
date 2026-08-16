A mutually recursive group where only one member is a record: make is
generated for the record and the non-record sibling is silently skipped
(matching native ppx_deriving, issue
https://github.com/ocaml-ppx/ppx_deriving/issues/272).

  $ cat > input.ml <<'EOF'
  > type principle = {
  >   prt1 : int;
  >   prt2 : secondary;
  > }
  > 
  > and secondary = string
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type principle = { prt1 : int; prt2 : secondary }
  and secondary = string [@@deriving make]
  
  include struct
    let _ = fun (_ : principle) -> ()
    let _ = fun (_ : secondary) -> ()
    let make_principle ~prt1 = fun ~prt2 -> { prt1; prt2 }
    let _ = make_principle
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A group of two records generates both constructors in one non-recursive value
group.

  $ cat > input.ml <<'EOF'
  > type a = { a1 : int }
  > and b = { b1 : string }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type a = { a1 : int }
  and b = { b1 : string } [@@deriving make]
  
  include struct
    let _ = fun (_ : a) -> ()
    let _ = fun (_ : b) -> ()
  
    let make_a ~a1 = { a1 }
    and make_b ~b1 = { b1 }
  
    let _ = make_a
    and _ = make_b
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
