# ppx_deriving_melange

`ppx_deriving_melange` is intended to be a Melange-compatible subset of
`ppx_deriving`.

The first supported deriver is `eq`:

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

## Current Scope

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

Unsupported for now:

- polymorphic variant row inheritance
- `ord`, `enum`, `iter`, and the rest of `ppx_deriving.std`

## Roadmap From `ppx_deriving.eq`

Native `ppx_deriving.eq` supports more cases than this package. These are useful
future milestones:

- standard containers: `ref`, `lazy_t`
- type aliases whose target type is not otherwise supported
- custom `[@nobuiltin]` handling
- expression extension support, e.g. `[%eq: t]`
