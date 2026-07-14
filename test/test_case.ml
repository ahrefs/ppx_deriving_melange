(* One runtime test case, shared verbatim by the native and Melange runners so
   both exercise the same generated code. Cases stay test-framework-agnostic by
   taking the assertion as a labelled argument: [run] calls
   [assert_bool_equal actual expected] on two bools. The native runner
   (test_eq.ml / test_iter.ml) wires it to OUnit2's [assert_equal]; the Melange
   runner (test_runtime.ml) wires it to node:assert's [strictEqual]. *)
type t = {
  name : string;
  run : assert_bool_equal:(bool -> bool -> unit) -> unit;
}
