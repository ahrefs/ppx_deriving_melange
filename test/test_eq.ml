open OUnit2

module Cases = Ppx_deriving_melange_runtime_cases.Test_eq_cases

let assert_bool_equal actual expected = assert_equal expected actual

let test_case ({ name; run } : Ppx_deriving_melange_runtime_cases.Test_case.t) =
  name >:: fun _ctxt -> run ~assert_bool_equal

let suite = "Test deriving(eq)" >::: List.map test_case Cases.all

let () = run_test_tt_main suite
