make is records-only. Every non-record shape is rejected with the same error,
and the attribute-misuse cases have their own messages.

Variants are rejected.

  $ cat > input.ml <<'EOF'
  > type t = A | B [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-32:
  1 | type t = A | B [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

Fully abstract types are rejected.

  $ cat > input.ml <<'EOF'
  > type t [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-24:
  1 | type t [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

Open (extensible) types are rejected.

  $ cat > input.ml <<'EOF'
  > type t = .. [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-29:
  1 | type t = .. [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

Tuple aliases are rejected.

  $ cat > input.ml <<'EOF'
  > type t = int * string [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-39:
  1 | type t = int * string [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

Polymorphic variants are rejected.

  $ cat > input.ml <<'EOF'
  > type t = [ `A | `B ] [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-38:
  1 | type t = [ `A | `B ] [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

An alias of a record type is rejected (it is an abstract manifest, not a record
declaration).

  $ cat > input.ml <<'EOF'
  > type r = { x : int }
  > type t = r [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 2, characters 0-28:
  2 | type t = r [@@deriving make]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]

Two `[@main]` fields is an error.

  $ cat > input.ml <<'EOF'
  > type t = {
  >   a : int; [@main]
  >   b : int; [@main]
  > }
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 3, characters 2-18:
  3 |   b : int; [@main]
        ^^^^^^^^^^^^^^^^
  Error: deriving.make doesn't support duplicate [@main] annotations
  [1]

`[@split]` on a field that is not `'a * 'b list` is an error.

  $ cat > input.ml <<'EOF'
  > type t = { xs : int [@split] } [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 11-28:
  1 | type t = { xs : int [@split] } [@@deriving make]
                 ^^^^^^^^^^^^^^^^^
  Error: deriving.make [@split] requires a field of type 'a * 'b list whose name ends in 's'
  [1]

`[@split]` on a field whose name does not end in `s` is an error.

  $ cat > input.ml <<'EOF'
  > type t = { item : int * int list [@split] } [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 11-41:
  1 | type t = { item : int * int list [@split] } [@@deriving make]
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: deriving.make [@split] requires a field of type 'a * 'b list whose name ends in 's'
  [1]

A mutually recursive group with no record members at all raises the first
error rather than silently producing nothing.

  $ cat > input.ml <<'EOF'
  > type t = A | B
  > and u = int * string
  > [@@deriving make]
  > EOF
  $ ./ppx_deriving_melange_standalone.exe -impl input.ml -o output.ml
  File "input.ml", line 1, characters 0-14:
  1 | type t = A | B
      ^^^^^^^^^^^^^^
  Error: deriving.make can be derived only for record types
  [1]
