open Fest

module Cases = Ppx_deriving_melange_runtime_cases.Test_runtime_cases

let assert_bool_equal actual expected = equal expect actual expected

let () =
  Cases.all
  |> List.iter (fun ({ name; run } : Cases.test_case) ->
    test (name ^ " runs in Melange") (fun () -> run ~assert_bool_equal))
