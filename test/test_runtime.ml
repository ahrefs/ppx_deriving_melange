open Fest

module Cases = Ppx_deriving_melange_runtime_cases.Test_eq_cases

let assert_bool_equal actual expected = equal expect actual expected

let () =
  Cases.all
  |> List.iter (fun ({ name; run } : Ppx_deriving_melange_runtime_cases.Test_case.t) ->
    test (name ^ " runs in Melange") (fun () -> run ~assert_bool_equal))
