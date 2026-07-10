open Fest

module Eq_cases = Ppx_deriving_melange_runtime_cases.Test_eq_cases
module Fold_cases = Ppx_deriving_melange_runtime_cases.Test_fold_cases
module Iter_cases = Ppx_deriving_melange_runtime_cases.Test_iter_cases
module Map_cases = Ppx_deriving_melange_runtime_cases.Test_map_cases
module Ord_cases = Ppx_deriving_melange_runtime_cases.Test_ord_cases
module Show_cases = Ppx_deriving_melange_runtime_cases.Test_show_cases

let assert_bool_equal actual expected = equal expect actual expected

let run_cases deriver cases =
  cases
  |> List.iter (fun ({ name; run } : Ppx_deriving_melange_runtime_cases.Test_case.t) ->
    test (deriver ^ " " ^ name ^ " runs in Melange") (fun () -> run ~assert_bool_equal))

let () =
  run_cases "eq" Eq_cases.all;
  run_cases "fold" Fold_cases.all;
  run_cases "iter" Iter_cases.all;
  run_cases "map" Map_cases.all;
  run_cases "ord" Ord_cases.all;
  run_cases "show" Show_cases.all
