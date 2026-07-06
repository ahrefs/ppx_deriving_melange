(lang dune 3.16)

(using melange 0.1)

(name ppx_deriving_melange)

(generate_opam_files true)

(maintainers
 "Ahrefs")

(authors
 "Ahrefs")

(license MIT)

(homepage "https://github.com/ahrefs/ppx_deriving_melange")

(bug_reports "https://github.com/ahrefs/ppx_deriving_melange/issues")

(source
 (github ahrefs/ppx_deriving_melange))

(package
 (name ppx_deriving_melange)
 (synopsis "Melange-compatible deriving plugins for OCaml")
 (description "A Melange-compatible subset of ppx_deriving: eq, iter, ord, and show.")
 (depends
  (ocaml
   (>= "5.0.0"))
  (dune
   (>= "3.16"))
  (ppxlib
   (> "0.36.0"))
  (melange
   (>= "5.0.0"))
  (ounit2 :with-test)
  (melange-fest :with-test)
  (ocamlformat
   (and
    (= "0.29.0")
    :with-dev-setup))
  (ocaml-lsp-server :with-dev-setup)
  (odoc-driver :with-doc))
 (tags
  ("org:ahrefs" syntax melange ppx)))
