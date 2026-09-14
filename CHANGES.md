# Unreleased

- add expression extensions `[%eq: t]`, `[%ord: t]`, and `[%show: t]`, plus the
  namespaced `[%derive.eq: t]`, `[%derive.ord: t]`, and `[%derive.show: t]`
  forms
- fix bare-attribute registration conflicts in the `eq`, `ord`, and `show`
  derivers
- support `[@printer]` on polymorphic variant tags in the `show` deriver,
  matching native `ppx_deriving` 6.2.0

# 0.2.0

- add `fold` deriver
- add `make` deriver
- fix a bare-attribute registration conflict in the `make` deriver

# 0.1.0

- Initial release, supporting the `eq`, `iter`, `map`, `ord`, and `show`
  derivers as a Melange-compatible subset of `ppx_deriving`
