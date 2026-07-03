# ppx_deriving_melange

`ppx_deriving_melange` is intended to be a Melange-compatible subset of
`ppx_deriving`.

Supported derivers: `eq`, `iter`, `ord`, and `show`.

## eq

```ocaml
type t =
  | A
  | B
[@@deriving eq]
```

This generates:

```ocaml
val equal : t -> t -> bool
```

For non-`t` type names, the generated function follows the usual
`ppx_deriving.eq` convention:

```ocaml
type filter_id =
  | FirstSeen
  | Volume
[@@deriving eq]

val equal_filter_id : filter_id -> filter_id -> bool
```

### eq scope

The initial version supports classic variants with:

- constructors without payloads
- tuple payload constructors
- primitive payloads: `string`, `int`, `bool`, `float`, `char`, `bytes`, `int32`, `Int32.t`, `int64`, `Int64.t`, and `unit`
- list payloads, e.g. `string list` and `Foo.t list`
- option payloads, e.g. `string option` and `Foo.t option`
- array payloads, e.g. `string array` and `Foo.t array`
- result payloads, e.g. `(string, error) result`
- tuple payloads, e.g. `int * string`
- custom equality on payload types via `[@equal ...]`
- simple type aliases whose target type is supported
- record types with supported field types
- record payload constructors with supported field types
- type parameters and generic type applications whose arguments are supported
- recursive type groups whose members use supported shapes
- closed polymorphic variants with supported payloads

For custom payload types, generated code follows the usual `ppx_deriving.eq`
name convention:

```ocaml
type t = Wrap of Foo.t [@@deriving eq]
```

uses:

```ocaml
Foo.equal
```

Custom equality can be provided on payload or field types with `[@equal ...]`.
For compatibility with native `ppx_deriving.eq`, the namespaced form
`[@deriving.eq.equal ...]` is also accepted.

## iter

`iter` generates a function that applies a callback to every value sitting at
a type-parameter position:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
[@@deriving iter]
```

This generates:

```ocaml
val iter_tree : ('a -> unit) -> 'a tree -> unit
```

Naming follows the same convention as `eq`: `type t` generates `iter`,
`type status` generates `iter_status`, and a reference to `Foo.t` uses
`Foo.iter`.

### iter scope

`iter` supports the same shapes as `eq`: variants (including tuple and
inline-record payloads), records, tuples, simple aliases, type parameters,
generic type applications, recursive type groups, closed polymorphic variants,
and `list`, `option`, `array`, and `result` payloads.

Matching native `ppx_deriving.iter`, a type expression with no free type
variables iterates as a no-op:

```ocaml
type t = Foo.t [@@deriving iter]
```

generates a `val iter : t -> unit` that does nothing — in particular,
`Foo.iter` is not required to exist (unlike `eq`, which needs `Foo.equal`).
This rule covers all primitive payloads, so iteration is only observable for
parameterized types.

Also matching native `ppx_deriving.iter`, there is no `[@iter ...]`
custom-function attribute. Functor-applied type paths (`Make(Arg).t`) and
polymorphic variant row inheritance are rejected with a clear error when they
are reached; monomorphic occurrences collapse to the no-op first, as in native
`ppx_deriving`.

## ord

`ord` generates a `compare` function — the same convention native
`ppx_deriving.ord` uses, so the result drops straight into `Map.Make` /
`Set.Make` and `List.sort`:

```ocaml
type t =
  | Red
  | Green
  | Blue
[@@deriving ord]
```

This generates:

```ocaml
val compare : t -> t -> int
```

Note the function is named `compare`, not `ord`: `type t` generates `compare`,
`type status` generates `compare_status`, and a reference to `Foo.t` uses
`Foo.compare`. Parameterized types take a comparison callback per type
parameter, e.g. `val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int`.

### ord semantics

Comparison matches native `ppx_deriving.ord`:

- variants and polymorphic variants are ordered by declaration order; within the
  same constructor, payloads are compared lexicographically
- records and tuples compare fields/elements lexicographically in declaration
  order
- `None < Some _`; `Ok _ < Error _`
- lists compare element-by-element (a prefix is smaller); arrays compare by
  length first, then elements
- primitives use a typed `Stdlib.compare`

### ord scope

`ord` supports the same shapes as `eq` (variants with tuple and inline-record
payloads, records, tuples, simple aliases, type parameters, generic type
applications, recursive type groups, closed polymorphic variants, and `list`,
`option`, `array`, `result`, and `unit`). Custom comparison can be provided on a
payload or field type with `[@compare ...]`; for compatibility with native
`ppx_deriving.ord`, the namespaced form `[@deriving.ord.compare ...]` is also
accepted.

As with `eq` and `iter`, `ref`, `lazy_t`, `nativeint`, functor-applied type
paths, and polymorphic variant row inheritance are rejected with a clear error
(native `ppx_deriving.ord` supports these, but they are out of scope here).

## show

`show` generates a structural debug printer: a Format-based `pp` plus a
`show` function that renders a value to a string in OCaml-like syntax:

```ocaml
type t =
  | Red
  | Green
  | Blue
[@@deriving show]
```

This generates:

```ocaml
val pp : Stdlib.Format.formatter -> t -> unit
val show : t -> string
```

Naming follows the usual convention: `type t` generates `pp`/`show`,
`type status` generates `pp_status`/`show_status`, and a reference to `Foo.t`
uses `Foo.pp`. Parameterized types take a printer callback per type parameter,
e.g. `val show : (Stdlib.Format.formatter -> 'a -> unit) -> 'a t -> string`.

### show output

Output matches native `ppx_deriving.show`:

- constructors print as `Zero`, `(One 5)`, `(Pair (1, "a"))`; inline-record
  payloads as `Item {rank = 1; label = "x"}`
- records print as `{ name = "a"; count = 1 }`
- primitives print in OCaml syntax: strings and chars quoted and escaped,
  floats via `%F`, `int32` as `7l`, `int64` as `9L`, `bytes` through
  `Bytes.to_string`, unit as `()`
- containers: `[1; 2]`, `[|3|]`, `(Some 1)`/`None`, `(Ok 1)`/`(Error "e")`
- polymorphic variants print as `` `All`` and `` `Name ("a")``
- functions print as `<fun>`

By default (`with_path = true`, native behavior) constructor names and the
first record field are qualified with the module path
(`Main_module.Sub.Red`); pass `{ with_path = false }` to drop it:

```ocaml
type t = Red [@@deriving show { with_path = false }]

(* show Red = "Red" *)
```

A re-exported definition (`type u = M.s = A | B`) prints the manifest's module
path (`M.A`), also matching native behavior.

### show attributes

A custom printer can be provided on a payload or field type with
`[@printer ...]`; the printer body may use a bare `fprintf`, which is aliased
to `Stdlib.Format.fprintf` as in native `ppx_deriving.show`. The namespaced
form `[@deriving.show.printer ...]` is also accepted:

```ocaml
type t = Named of (string[@printer fun fmt -> fprintf fmt "name=%s"])
[@@deriving show { with_path = false }]

(* show (Named "x") = "(Named name=x)" *)
```

`[@printer]` is also accepted on a constructor declaration; the printer
receives `fmt` and the payload packed as one value (`()`, the single payload,
or a tuple), or one argument per field for inline-record payloads:

```ocaml
type t =
  | First [@printer fun fmt _ -> Format.pp_print_string fmt "first"]
  | Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
[@@deriving show]

(* show First = "first", show (Second 42) = "second: 42" *)
```

`[@opaque]` (or `[@deriving.show.opaque]`) prints `<opaque>` without
traversing the value:

```ocaml
type t = { secret : (string[@opaque]) } [@@deriving show]
```

### show scope

`show` supports the same shapes as `eq`/`ord` (variants with tuple and
inline-record payloads, records, tuples, simple aliases, type parameters,
generic type applications, recursive type groups, closed polymorphic variants,
and `list`, `option`, `array`, `result`, and `unit`), plus arrow types
(printed as `<fun>`).

As with the other derivers, `ref`, `lazy_t`, `nativeint`, functor-applied type
paths, and polymorphic variant row inheritance are out of scope (native
`ppx_deriving.show` supports these). `[@polyprinter]` and `[@nobuiltin]` are
not supported either.

## Unsupported for now

- polymorphic variant row inheritance
- `enum` and the rest of `ppx_deriving.std`

## Roadmap From `ppx_deriving`

Native `ppx_deriving` supports more cases than this package. These are useful
future milestones:

- standard containers: `ref`, `lazy_t`
- type aliases whose target type is not otherwise supported
- custom `[@nobuiltin]` handling
- expression extension support, e.g. `[%eq: t]` / `[%show: t]`
- `show`'s `[@polyprinter]` attribute
- `map` and `fold` derivers sharing the same traversal style as `iter`
