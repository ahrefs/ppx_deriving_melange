# ppx_deriving_melange

`ppx_deriving_melange` is intended to be a Melange-compatible subset of
`ppx_deriving`.

Supported derivers: `eq` and `iter`.

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
- primitive payloads: `string`, `int`, `bool`, `float`, `char`, `bytes`, `int32`, `Int32.t`, `int64`, and `Int64.t`
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

## Unsupported for now

- polymorphic variant row inheritance
- `ord`, `enum`, `show`, and the rest of `ppx_deriving.std`

## Roadmap From `ppx_deriving`

Native `ppx_deriving` supports more cases than this package. These are useful
future milestones:

- standard containers: `ref`, `lazy_t`
- type aliases whose target type is not otherwise supported
- custom `[@nobuiltin]` handling
- expression extension support, e.g. `[%eq: t]`
- `map` and `fold` derivers sharing the same traversal style as `iter`
