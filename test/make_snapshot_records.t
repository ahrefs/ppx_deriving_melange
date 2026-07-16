Snapshot generated code for a record with every field kind: a plain field, an
option field, a list field, and a defaulted field. Optionals close with a
trailing unit argument.

  $ cat > input.ml <<'EOF'
  > type status = {
  >   id : int;
  >   note : string option;
  >   tags : string list;
  >   retries : int; [@default 3]
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type status = {
    id : int;
    note : string option;
    tags : string list;
    retries : int; [@default 3]
  }
  [@@deriving make]
  
  include struct
    let _ = fun (_ : status) -> ()
  
    let make_status ~id =
     fun ?note ->
      fun ?(tags = []) ->
       fun ?(retries = 3) -> fun () -> { id; note; tags; retries }
  
    let _ = make_status
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A `[@main]` field becomes the final positional argument and replaces the unit.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   level : int option;
  >   message : string; [@main]
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { level : int option; message : string [@main] } [@@deriving make]
  
  include struct
    let _ = fun (_ : t) -> ()
    let make ?level = fun message -> { level; message }
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A record with neither optionals nor a `[@main]` field gets no trailing unit.

  $ cat > input.ml <<'EOF'
  > type pair = {
  >   first : int;
  >   second : string;
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type pair = { first : int; second : string } [@@deriving make]
  
  include struct
    let _ = fun (_ : pair) -> ()
    let make_pair ~first = fun ~second -> { first; second }
    let _ = make_pair
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

`[@split]` on an `'a * 'b list` field whose name ends in `s` splits into a
required singular argument and an optional plural argument defaulting to `[]`.

  $ cat > input.ml <<'EOF'
  > type t = { authors : string * string list [@split] } [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { authors : string * string list [@split] } [@@deriving make]
  
  include struct
    let _ = fun (_ : t) -> ()
  
    let make ~author =
     fun ?(authors = []) ->
      let authors = (author, authors) in
      fun () -> { authors }
  
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

`[@default]` beats the option/list shape: a `_ option [@default ...]` field is
optional with the given default rather than defaulting to None.

  $ cat > input.ml <<'EOF'
  > type t = { value : int option [@default Some 0] } [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { value : int option [@default Some 0] } [@@deriving make]
  
  include struct
    let _ = fun (_ : t) -> ()
    let make ?(value = Some 0) = fun () -> { value }
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

The namespaced attribute spellings and the core-type attachment point expand
identically to the plain, label-attached forms.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   a : int; [@deriving.make.default 1]
  >   b : (int[@deriving.make.default 2]);
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = {
    a : int; [@deriving.make.default 1]
    b : (int[@deriving.make.default 2]);
  }
  [@@deriving make]
  
  include struct
    let _ = fun (_ : t) -> ()
    let make ?(a = 1) = fun ?(b = 2) -> fun () -> { a; b }
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]

A `Stdlib.`-qualified option is matched on bare `Lident` only, so it becomes a
required labelled argument (documented divergence from native, which strips the
prefix).

  $ cat > input.ml <<'EOF'
  > type t = { value : int Stdlib.option } [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  $ ocamlformat --enable-outside-detected-project --impl output.ml
  type t = { value : int Stdlib.option } [@@deriving make]
  
  include struct
    let _ = fun (_ : t) -> ()
    let make ~value = { value }
    let _ = make
  end [@@ocaml.doc "@inline"] [@@merlin.hide]
