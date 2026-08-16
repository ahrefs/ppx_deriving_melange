# ppx_deriving_melange

`ppx_deriving_melange` is a Melange-compatible subset of `ppx_deriving`.

| Deriver | Generates | What for |
|---|---|---|
| [`eq`](#eq) | `equal : t -> t -> bool` | structural equality |
| [`ord`](#ord) | `compare : t -> t -> int` | ordering for `Map.Make`, `Set.Make`, `List.sort` |
| [`iter`](#iter) | `iter : ('a -> unit) -> 'a t -> unit` | visit every value at a type parameter |
| [`map`](#map) | `map : ('a -> 'b) -> 'a t -> 'b t` | transform every value at a type parameter |
| [`fold`](#fold) | `fold : ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b` | accumulate over values at a type parameter |
| [`make`](#make) | `make : id:int -> ?note:string -> unit -> t` | smart constructor for a record |
| [`show`](#show) | `show : t -> string` plus a Format-based `pp` | structural debug printer |

`eq`, `ord`, and `show` are also available inline, as
[expression extensions](#expression-extensions): `[%eq: t]`, `[%ord: t]`,
`[%show: t]`.

## Installation

```
opam install ppx_deriving_melange
```

Then add the ppx to the `preprocess` field of the library or executable that
uses it:

```
(library
 (name my_lib)
 (modes melange)
 (preprocess
  (pps ppx_deriving_melange)))
```

## Usage

Attach `[@@deriving <deriver>]` to a type declaration, in either a structure or
a signature. Several derivers can be requested at once by separating their
names with commas:

```ocaml
type t = {
  id : int;
  name : string;
}
[@@deriving eq, show]
```

A deriver that takes options accepts them as a record after its name:

```ocaml
type t = Red [@@deriving show { with_path = false }]
```

Generated names follow the `ppx_deriving` convention: a type named `t` gives
unprefixed names (`equal`, `compare`, `show`), and any other type name is
suffixed (`equal_status`, `compare_status`, `show_status`). A payload
referring to `Foo.t` composes through `Foo.equal`, `Foo.compare`, `Foo.show`,
and so on.

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

## map

`map` generates a function that rebuilds a value with every type-parameter
position transformed — the structural counterpart of `iter`:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
[@@deriving map]
```

This generates:

```ocaml
val map_tree : ('a -> 'b) -> 'a tree -> 'b tree
```

Naming follows the same convention as the other derivers: `type t` generates
`map`, `type status` generates `map_status`, and a reference to `Foo.t` uses
`Foo.map`. Each type parameter takes its own callback, with a fresh result
variable per parameter:

```ocaml
type ('a, 'b) t = Left of 'a | Right of 'b [@@deriving map]

val map : ('a -> 'c) -> ('b -> 'd) -> ('a, 'b) t -> ('c, 'd) t
```

Result variable names are the first free letters not used by the declared
parameters (so `('k, 'v) t` maps with `('k -> 'a) -> ('v -> 'b) -> ...`).

### map semantics

Matching native `ppx_deriving.map`, a type expression with no free type
variables maps as the identity:

```ocaml
type t = Foo.t [@@deriving map]
```

generates a `val map : t -> t` that returns its argument unchanged — in
particular, `Foo.map` is not required to exist (unlike `eq`, which needs
`Foo.equal`). Constructors, record fields, and containers are rebuilt with
their shape preserved: `List.map`/`Array.map` for lists and arrays,
`None`/`Some`, `Ok`/`Error`, and tuples element by element.

### map scope

`map` supports the same shapes as `iter`: variants (including tuple and
inline-record payloads), records, tuples, simple aliases, type parameters,
generic type applications, recursive type groups, closed polymorphic variants,
and `list`, `option`, `array`, and `result` payloads.

Also matching native `ppx_deriving.map`, there is no `[@map ...]`
custom-function attribute. Functor-applied type paths (`Make(Arg).t`) and
polymorphic variant row inheritance are rejected with a clear error when they
are reached; monomorphic occurrences collapse to the identity first, as in
native `ppx_deriving`.

## fold

`fold` threads an accumulator through every type-parameter position, in lexical order:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
[@@deriving fold]
```

This generates:

```ocaml
val fold_tree : ('b -> 'a -> 'b) -> 'b -> 'a tree -> 'b
```

so `fold_tree (+) 0` sums an `int tree`. Naming follows the usual convention:
`type t` generates `fold`, `type status` generates `fold_status`, and a
reference to `Foo.t` uses `Foo.fold`. Callbacks are `fold_left`-style
(`acc -> element -> acc`), one per type parameter, all sharing a single
accumulator type variable — the first free letter not used by the declared
parameters:

```ocaml
type ('a, 'b) t = Left of 'a | Right of 'b [@@deriving fold]

val fold : ('c -> 'a -> 'c) -> ('c -> 'b -> 'c) -> 'c -> ('a, 'b) t -> 'c
```

### fold semantics

Matching native `ppx_deriving.fold`, a type expression with no free type
variables folds as the accumulator passthrough:

```ocaml
type t = Foo.t [@@deriving fold]
```

generates a `val fold : 'a -> t -> 'a` that returns the accumulator
unchanged — `Foo.fold` is not required to exist. Values at parameter
positions are visited in lexical order: record fields and constructor
payloads in declaration order, list/array elements left to right
(`List.fold_left`/`Array.fold_left`), tuple components left to right;
`None` and constant constructors return the accumulator as-is.

### fold scope

`fold` supports the same shapes as `iter` and `map`: variants (including
tuple and inline-record payloads), records, tuples, simple aliases, type
parameters, generic type applications, recursive type groups, closed
polymorphic variants, and `list`, `option`, `array`, and `result` payloads.

Also matching native `ppx_deriving.fold`, there is no `[@fold ...]`
custom-function attribute. Functor-applied type paths (`Make(Arg).t`) and
polymorphic variant row inheritance are rejected with a clear error when
they are reached; monomorphic occurrences collapse to the passthrough first.

## make

`make` generates a smart constructor for a record type — a function that takes
each field as an argument and returns the record. Unlike the other derivers it
does not traverse types; it is records-only.

```ocaml
type status = {
  id : int;
  note : string option;
  tags : string list;
  retries : int; [@default 3]
}
[@@deriving make]
```

This generates:

```ocaml
val make_status : id:int -> ?note:string -> ?tags:string list -> ?retries:int -> unit -> status
```

so `make_status ~id:1 ()` builds `{ id = 1; note = None; tags = []; retries = 3 }`.
Naming follows the usual convention: `type t` generates `make`, `type status`
generates `make_status`.

### make field mapping

Each field becomes an argument, in declaration order:

| field                          | argument                                              |
|--------------------------------|-------------------------------------------------------|
| `f : ty`                       | required labelled `~f`                                |
| `f : ty option`                | optional `?f` (`None` when omitted)                   |
| `f : ty list`                  | optional `?f` defaulting to `[]`                      |
| `f : ty [@default e]`          | optional `?f` defaulting to `e`                       |
| `f : ty [@main]`               | final positional (unlabelled) argument                |
| `fs : a * b list [@split]`     | required `~f:a` plus optional `?fs:b list` (`[]`)     |

A trailing `unit` argument is added when the record has optional arguments and
no `[@main]` field (it lets the optionals be applied); a `[@main]` field closes
the function instead; a record with neither gets no trailing unit
(`make_pair ~first ~second`). The `[@default]`, `[@main]`, and `[@split]`
attributes are also accepted in the namespaced form
(`[@deriving.make.default]`, etc.).

### make scope

Records only; every other shape (variants, abstract, open, tuple/alias, and
polymorphic-variant manifests) is rejected with a clear error. A mutually
recursive group is handled leniently, matching native `ppx_deriving`
([issue #272](https://github.com/ocaml-ppx/ppx_deriving/issues/272)): `make`
is generated for the record members and non-record members are skipped. Two notes on the semantics that differ from native: builtin
option/list detection matches on the bare `Lident` only, so a
`Stdlib.option`-typed field becomes a required argument rather than an optional
one; and a `[@default]` expression is inlined directly, so it can capture an
argument that shares an earlier field's name.

## show

`show` generates a structural debug printer: a Format-based `pp` plus a
`show` function that renders a value to a string in OCaml-like syntax.
`show` builds the string directly (without Format) whenever the type allows
it — see [show and Melange bundle size](#show-and-melange-bundle-size):

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

Output matches native `ppx_deriving.show`, with one intentional exception:
values longer than Format's margin (80 columns) print on a single line from
`show`, where native wraps them (`pp` wraps exactly like native):

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

### show and Melange bundle size

Melange compiles `Stdlib.Format` to a large amount of JavaScript. To keep
frontend bundles small, `show` builds its string directly (`string_of_int`,
`String.escaped`, `^`) whenever the type allows it, composing through other
types' `show` functions — code that only calls `show` does not need Format at
all. `pp` stays Format-based for native parity, `%a` composition, and
`[@printer]` support.

`show` falls back to Format (`asprintf "%a" pp`) when a formatter is really
needed: type parameters (the callbacks are printers), custom `[@printer]`
attributes, or applications of parameterized types such as `int Box.t`.

Bundler note: the generated module still imports Format because of `pp`, and
melange marks Format as having side effects, so bundlers keep the import even
when `pp` is unused. To let the bundler drop it, mark melange stdlib modules
side-effect-free, e.g. with an esbuild plugin:

```js
build.onResolve({ filter: /^melange\// }, (args) => ({
  path: resolveMelangePath(args.path),
  sideEffects: false,
}));
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

## Expression extensions

`eq`, `ord`, and `show` are also available as expression extensions, so the
generated logic can be used inline on any closed type, without declaring a
type or a named function first:

```ocaml
List.sort [%ord: int * string] pairs

assert_equal ~printer:[%show: (int * string) list] ~cmp:[%eq: (int * string) list] expected actual

print_endline ([%show: int option list] values)
```

| Extension | Type |
|---|---|
| `[%eq: t]` | `t -> t -> bool` |
| `[%ord: t]` | `t -> t -> int` |
| `[%show: t]` | `t -> string` |

Each is also accepted in the namespaced form (`[%derive.eq: t]`,
`[%derive.ord: t]`, `[%derive.show: t]`), matching native `ppx_deriving`.
Extensions compose exactly like payload types do, so `[%show: Foo.t]` uses
`Foo.show`, `[%eq: Foo.t]` uses `Foo.equal`, and `[%ord: Foo.t]` uses
`Foo.compare`.

Matching native `ppx_deriving`, there is no `[%compare: ...]` (the comparison
extension is `[%ord: ...]`; leaving `compare` unclaimed also avoids colliding
with `ppx_compare`) and no `[%pp: ...]`.

`[%show: t]` follows the same strategy as the generated `show` function: it
builds the string directly, and falls back to
`Stdlib.Format.asprintf "%a"` over `pp` only where a formatter is genuinely
required (custom `[@printer]`s and applications of parameterized types such as
`int Box.t`) — so inline use costs no more bundle size than a derived `show`.

## Unsupported for now

- polymorphic variant row inheritance
- `enum` and the rest of `ppx_deriving.std`

## Roadmap From `ppx_deriving`

Native `ppx_deriving` supports more cases than this package. These are useful
future milestones:

- standard containers: `ref`, `lazy_t`
- type aliases whose target type is not otherwise supported
- custom `[@nobuiltin]` handling
- `show`'s `[@polyprinter]` attribute

## Attribution

`ppx_deriving_melange` reimplements a subset of
[`ppx_deriving`](https://github.com/ocaml-ppx/ppx_deriving) by whitequark and
contributors. The derivers were written fresh for Melange, but their
semantics, the documentation examples, and the test scenarios are closely
modeled on the upstream plugins. `ppx_deriving` is distributed under the MIT
license; its copyright notice is reproduced in this repository's
[LICENSE](LICENSE) file.
