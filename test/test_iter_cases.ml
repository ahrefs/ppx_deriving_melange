module Parameterized_variant = struct
  type 'a t =
    | Value of 'a
    | Pair of 'a * 'a
    | Missing
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let visit value = iter (fun v -> collected := v :: !collected) value in
    visit (Value 1);
    visit (Pair (2, 3));
    visit Missing;
    assert_bool_equal (List.rev !collected = [ 1; 2; 3 ]) true
end

module Container_payloads = struct
  type 'a t = {
    items : 'a list;
    maybe : 'a option;
    scores : 'a array;
    outcome : ('a, 'a) result;
  }
  [@@deriving iter]

  let collect value =
    let collected = ref [] in
    iter (fun v -> collected := v :: !collected) value;
    List.rev !collected

  let run ~assert_bool_equal =
    assert_bool_equal
      (collect { items = [ 1; 2 ]; maybe = Some 3; scores = [| 4; 5 |]; outcome = Error 6 } = [ 1; 2; 3; 4; 5; 6 ])
      true;
    assert_bool_equal (collect { items = []; maybe = None; scores = [||]; outcome = Ok 9 } = [ 9 ]) true
end

module Nested_containers = struct
  type 'a t = Nested of 'a list option [@@deriving iter]

  let collect value =
    let collected = ref [] in
    iter (fun v -> collected := v :: !collected) value;
    List.rev !collected

  let run ~assert_bool_equal =
    assert_bool_equal (collect (Nested (Some [ 1; 2 ])) = [ 1; 2 ]) true;
    assert_bool_equal (collect (Nested None) = []) true
end

module Tuple_payload = struct
  type 'a t = Pair of ('a * string) [@@deriving iter]

  type 'a alias = 'a * 'a [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    iter (fun v -> collected := v :: !collected) (Pair (1, "ignored"));
    iter_alias (fun v -> collected := v :: !collected) (2, 3);
    assert_bool_equal (List.rev !collected = [ 1; 2; 3 ]) true
end

module Record_payload_constructor = struct
  type 'a t =
    | Empty
    | Item of {
        value : 'a;
        label : string;
        extras : 'a list;
      }
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let visit value = iter (fun v -> collected := v :: !collected) value in
    visit Empty;
    visit (Item { value = 1; label = "ignored"; extras = [ 2; 3 ] });
    assert_bool_equal (List.rev !collected = [ 1; 2; 3 ]) true
end

module Recursive_tree = struct
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let tree = Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)) in
    iter_tree (fun v -> collected := v :: !collected) tree;
    assert_bool_equal (List.rev !collected = [ 1; 2; 3 ]) true
end

module Mutually_recursive = struct
  type 'a rule = {
    terms : string list;
    search_location : 'a;
  }
  and 'a rule_group = { rules : 'a t list }
  and 'a t =
    | Rule of 'a rule
    | Group of 'a rule_group
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let value =
      Group { rules = [ Rule { terms = [ "title" ]; search_location = 1 }; Rule { terms = []; search_location = 2 } ] }
    in
    iter (fun v -> collected := v :: !collected) value;
    assert_bool_equal (List.rev !collected = [ 1; 2 ]) true
end

module Two_parameters = struct
  type ('a, 'b) t =
    | Left of 'a
    | Right of 'b
    | Both of 'a * 'b
  [@@deriving iter]

  let run ~assert_bool_equal =
    let ints = ref [] in
    let strings = ref [] in
    let visit value = iter (fun i -> ints := i :: !ints) (fun s -> strings := s :: !strings) value in
    visit (Left 1);
    visit (Right "a");
    visit (Both (2, "b"));
    assert_bool_equal (List.rev !ints = [ 1; 2 ]) true;
    assert_bool_equal (List.rev !strings = [ "a"; "b" ]) true
end

module Two_parameter_record = struct
  type ('a, 'b) t = {
    first : 'a;
    second : 'b;
  }
  [@@deriving iter]

  (* Mirrors the native ppx_deriving regression test for issue #82: each field
     must be visited by the callback matching its own type parameter, in
     declaration order. *)
  let run ~assert_bool_equal =
    let collected = ref [] in
    iter
      (fun a -> collected := ("a:" ^ string_of_int a) :: !collected)
      (fun b -> collected := ("b:" ^ b) :: !collected)
      { first = 1; second = "x" };
    assert_bool_equal (List.rev !collected = [ "a:1"; "b:x" ]) true
end

module Recursive_record_payload = struct
  type 'a t =
    | Leaf
    | Node of {
        left : 'a t;
        value : 'a;
        right : 'a t;
      }
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let tree = Node { left = Node { left = Leaf; value = 1; right = Leaf }; value = 2; right = Leaf } in
    iter (fun v -> collected := v :: !collected) tree;
    assert_bool_equal (List.rev !collected = [ 1; 2 ]) true
end

module Phantom_parameter = struct
  type 'a t = Id of int [@@deriving iter]

  let run ~assert_bool_equal =
    let called = ref false in
    iter (fun _ -> called := true) (Id 1);
    assert_bool_equal !called false
end

module Monomorphic_noop = struct
  module Plain = struct
    type t = T of int
  end

  type t = {
    name : string;
    plain : Plain.t;
    counts : int list;
  }
  [@@deriving iter]

  (* Plain has no iter function: deriving must not require one for monomorphic
     fields, and the generated iter must be a safe no-op. *)
  let run ~assert_bool_equal =
    iter { name = "a"; plain = Plain.T 1; counts = [ 1; 2 ] };
    assert_bool_equal true true
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving iter]
  end

  type 'a t = Boxed of 'a Box.t [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    iter (fun v -> collected := v :: !collected) (Boxed (Box.Box 7));
    assert_bool_equal (!collected = [ 7 ]) true
end

module Polymorphic_variant = struct
  type 'a t =
    [ `All
    | `Value of 'a
    ]
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let visit value = iter (fun v -> collected := v :: !collected) value in
    visit `All;
    visit (`Value 5);
    assert_bool_equal (!collected = [ 5 ]) true
end

module Status_naming = struct
  type 'a status = Active of 'a [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    iter_status (fun v -> collected := v :: !collected) (Active 4);
    assert_bool_equal (!collected = [ 4 ]) true
end

module Module_signature = struct
  module M : sig
    type 'a t = Wrap of 'a [@@deriving iter]
  end = struct
    type 'a t = Wrap of 'a [@@deriving iter]
  end

  let run ~assert_bool_equal =
    let collected = ref [] in
    M.iter (fun v -> collected := v :: !collected) (M.Wrap 4);
    assert_bool_equal (!collected = [ 4 ]) true
end

module Recursive_group_alias = struct
  type 'a pair = 'a * 'a
  and 'a t = 'a pair [@@deriving iter]

  let run ~assert_bool_equal =
    let count = ref 0 in
    iter (fun _element -> incr count) (1, 2);
    assert_bool_equal (!count = 2) true
end

module Monomorphic_group_alias = struct
  type a = A of int
  and b = a [@@deriving iter]

  let run ~assert_bool_equal =
    (* iter_b is the no-op: it must exist and do nothing *)
    iter_b (A 1);
    assert_bool_equal true true
end

module Fragile_match_regression = struct
  [@@@ocaml.warning "@4"]

  type 'a t =
    | A
    | B of 'a
    | C of { x : 'a }
  [@@deriving iter]

  type 'a pv =
    [ `A
    | `B of 'a
    ]
  [@@deriving iter]

  let run ~assert_bool_equal =
    let collected = ref [] in
    let visit value = iter (fun v -> collected := v :: !collected) value in
    visit A;
    visit (B 1);
    visit (C { x = 2 });
    iter_pv (fun v -> collected := v :: !collected) `A;
    iter_pv (fun v -> collected := v :: !collected) (`B 3);
    assert_bool_equal (List.rev !collected = [ 1; 2; 3 ]) true
end

let all : Test_case.t list =
  [
    { name = "parameterized_variant"; run = Parameterized_variant.run };
    { name = "container_payloads"; run = Container_payloads.run };
    { name = "nested_containers"; run = Nested_containers.run };
    { name = "tuple_payload"; run = Tuple_payload.run };
    { name = "record_payload_constructor"; run = Record_payload_constructor.run };
    { name = "recursive_tree"; run = Recursive_tree.run };
    { name = "mutually_recursive"; run = Mutually_recursive.run };
    { name = "two_parameters"; run = Two_parameters.run };
    { name = "two_parameter_record"; run = Two_parameter_record.run };
    { name = "recursive_record_payload"; run = Recursive_record_payload.run };
    { name = "phantom_parameter"; run = Phantom_parameter.run };
    { name = "monomorphic_noop"; run = Monomorphic_noop.run };
    { name = "generic_application"; run = Generic_application.run };
    { name = "polymorphic_variant"; run = Polymorphic_variant.run };
    { name = "status_naming"; run = Status_naming.run };
    { name = "module_signature"; run = Module_signature.run };
    { name = "recursive_group_alias"; run = Recursive_group_alias.run };
    { name = "monomorphic_group_alias"; run = Monomorphic_group_alias.run };
    { name = "fragile_match_regression"; run = Fragile_match_regression.run };
  ]
