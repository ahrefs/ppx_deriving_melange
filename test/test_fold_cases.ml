module Parameterized_variant = struct
  type 'a t =
    | Value of 'a
    | Pair of 'a * 'a
    | Fixed of string
    | Missing
  [@@deriving fold]

  let run ~assert_bool_equal =
    let sum = fold ( + ) 0 in
    assert_bool_equal (sum (Value 1) = 1) true;
    assert_bool_equal (sum (Pair (2, 3)) = 5) true;
    assert_bool_equal (sum (Fixed "kept") = 0) true;
    assert_bool_equal (sum Missing = 0) true;
    assert_bool_equal (fold (fun acc v -> acc ^ string_of_int v) "!" (Pair (1, 2)) = "!12") true
end

module Container_payloads = struct
  type 'a t = {
    items : 'a list;
    maybe : 'a option;
    scores : 'a array;
    outcome : ('a, 'a) result;
  }
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal
      (fold ( + ) 0 { items = [ 1; 2 ]; maybe = Some 3; scores = [| 4; 5 |]; outcome = Error 6 } = 21)
      true;
    assert_bool_equal (fold ( + ) 0 { items = []; maybe = None; scores = [||]; outcome = Ok 9 } = 9) true
end

module Nested_containers = struct
  type 'a t = Nested of 'a list option [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold ( + ) 0 (Nested (Some [ 1; 2 ])) = 3) true;
    assert_bool_equal (fold ( + ) 0 (Nested None) = 0) true
end

module Tuple_payload = struct
  type 'a t = Pair of ('a * string) [@@deriving fold]
  type 'a alias = 'a * string [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold ( + ) 1 (Pair (2, "kept")) = 3) true;
    assert_bool_equal (fold_alias ( + ) 1 (2, "kept") = 3) true
end

module Record_payload_constructor = struct
  type 'a t =
    | Empty
    | Item of {
        value : 'a;
        label : string;
        extras : 'a list;
      }
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold ( + ) 0 Empty = 0) true;
    assert_bool_equal (fold ( + ) 0 (Item { value = 1; label = "kept"; extras = [ 2; 3 ] }) = 6) true
end

module Recursive_tree = struct
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving fold]

  (* Mirrors the native ppx_deriving fold test: summing a btree. *)
  let run ~assert_bool_equal =
    let tree = Node (Node (Leaf, 3, Leaf), 1, Node (Leaf, 2, Leaf)) in
    assert_bool_equal (fold_tree ( + ) 0 tree = 6) true
end

module Recursive_two_parameters = struct
  type ('a, 'b) t =
    | Left of 'a
    | Flag of bool
    | Chain of 'b * ('a, 'b) t
  [@@deriving fold]

  let run ~assert_bool_equal =
    let collect = fold (fun acc v -> acc ^ string_of_int v) (fun acc s -> acc ^ s) "" in
    assert_bool_equal (collect (Chain ("a", Chain ("b", Left 1))) = "ab1") true;
    assert_bool_equal (collect (Chain ("a", Flag true)) = "a") true
end

module Recursive_record_payload = struct
  type 'a t =
    | Node of {
        left : 'a t;
        value : 'a;
        right : 'a t;
      }
    | Leaf
  [@@deriving fold]

  let run ~assert_bool_equal =
    let tree = Node { left = Node { left = Leaf; value = 1; right = Leaf }; value = 2; right = Leaf } in
    assert_bool_equal (fold ( + ) 0 tree = 3) true
end

module Cross_type_record_payload = struct
  (* Mirrors native's btreer: an inline-record payload whose fields reference
     a different derived type, so the generated code composes fold_tree. *)
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving fold]

  type 'a t =
    | Wrapper of {
        lft : 'a tree;
        elt : 'a;
        rgt : 'a tree;
      }
    | Nothing
  [@@deriving fold]

  let run ~assert_bool_equal =
    let value = Wrapper { lft = Node (Leaf, 1, Leaf); elt = 2; rgt = Node (Leaf, 3, Leaf) } in
    assert_bool_equal (fold ( + ) 0 value = 6) true;
    let collected = fold (fun acc v -> v :: acc) [] value in
    assert_bool_equal (List.rev collected = [ 1; 2; 3 ]) true;
    assert_bool_equal (fold ( + ) 5 Nothing = 5) true
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
  [@@deriving fold]

  let run ~assert_bool_equal =
    let value =
      Group { rules = [ Rule { terms = [ "title" ]; search_location = 1 }; Rule { terms = []; search_location = 2 } ] }
    in
    assert_bool_equal (fold ( + ) 0 value = 3) true
end

module Lexical_order = struct
  type 'a t = {
    first : 'a;
    items : 'a list;
    pair : 'a * 'a;
    last : 'a;
  }
  [@@deriving fold]

  (* Fold's traversal order is part of its contract (native: "in lexical
     order"): fields in declaration order, list elements left to right,
     tuple components left to right. *)
  let run ~assert_bool_equal =
    let collected = fold (fun acc v -> v :: acc) [] { first = 1; items = [ 2; 3 ]; pair = 4, 5; last = 6 } in
    assert_bool_equal (List.rev collected = [ 1; 2; 3; 4; 5; 6 ]) true
end

module Parameter_positions_only = struct
  type 'a t =
    | Value of 'a
    | Fixed of string
  [@@deriving fold]

  (* fold visits values at type-parameter positions, not values of a matching
     type: instantiated at string, a Fixed payload is not folded even though
     the callback could apply to it. *)
  let run ~assert_bool_equal =
    let concat = fold (fun acc s -> acc ^ s) "" in
    assert_bool_equal (concat (Value "v") = "v") true;
    assert_bool_equal (concat (Fixed "kept") = "") true
end

module Callback_call_count = struct
  type 'a t = {
    single : 'a;
    pair : 'a * 'a;
    items : 'a list;
    maybe : 'a option;
  }
  [@@deriving fold]

  (* The callback runs exactly once per value at a parameter position; the
     accumulator itself does the counting. *)
  let run ~assert_bool_equal =
    let count = fold (fun acc _ -> acc + 1) 0 { single = 1; pair = 2, 3; items = [ 4; 5; 6 ]; maybe = Some 7 } in
    assert_bool_equal (count = 7) true
end

module Two_parameters = struct
  type ('a, 'b) t =
    | Left of 'a
    | Right of 'b
    | Both of 'a * 'b
  [@@deriving fold]

  (* Mirrors the native fold test on result: one shared accumulator, one
     callback per parameter ((+) for 'a, (-) for 'b). *)
  let run ~assert_bool_equal =
    let f = fold ( + ) ( - ) 0 in
    assert_bool_equal (f (Left 1) = 1) true;
    assert_bool_equal (f (Right 1) = -1) true;
    assert_bool_equal (f (Both (2, 1)) = 1) true
end

module Two_parameter_record = struct
  type ('a, 'b) t = {
    first : 'a;
    second : 'b;
  }
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal
      (fold (fun acc a -> acc ^ string_of_int a) (fun acc b -> acc ^ b) "" { first = 1; second = "x" } = "1x")
      true
end

module Recursive_group_alias = struct
  type 'a pair = 'a * 'a
  and 'a t = 'a pair [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold ( + ) 0 (1, 2) = 3) true
end

module Monomorphic_group_alias = struct
  type a = A of int
  and b = a [@@deriving fold]

  let run ~assert_bool_equal =
    (* fold_b is the accumulator passthrough: it must exist and change nothing *)
    assert_bool_equal (fold_b 41 (A 1) = 41) true
end

module Group_with_distinct_parameter_names = struct
  (* Regression (map review carry-over): the let-rec annotations quantify
     their type variables per binding; with group-scoped variables u's 'b
     would unify with t's variables and reject this heterogeneous fold. *)
  type 'a t = A of 'a
  and 'b u = B of 'b t [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold_u (fun acc v -> acc ^ string_of_int v) "!" (B (A 1)) = "!1") true
end

module Group_instantiating_sibling = struct
  (* Regression (map review carry-over): folding a sibling instantiated at a
     composite argument requires polymorphic recursion across the group. *)
  type 'a t = A of 'a
  and 'a u = B of ('a * 'a) t [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold_u ( + ) 0 (B (A (1, 2))) = 3) true
end

module Fragile_match_regression = struct
  [@@@ocaml.warning "@4"]

  type 'a t =
    | A
    | B of 'a
    | C of { x : 'a }
  [@@deriving fold]

  type 'a pv =
    [ `A
    | `B of 'a
    ]
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold ( + ) 0 A = 0) true;
    assert_bool_equal (fold ( + ) 0 (B 1) = 1) true;
    assert_bool_equal (fold ( + ) 0 (C { x = 2 }) = 2) true;
    assert_bool_equal (fold_pv ( + ) 0 `A = 0) true;
    assert_bool_equal (fold_pv ( + ) 0 (`B 3) = 3) true
end

module Phantom_parameter = struct
  type 'a t = Id of int [@@deriving fold]

  let run ~assert_bool_equal =
    let called = ref false in
    let folded =
      fold
        (fun acc _ ->
          called := true;
          acc)
        7 (Id 1)
    in
    assert_bool_equal (folded = 7) true;
    assert_bool_equal !called false
end

module Monomorphic_variant = struct
  type t =
    | Zero
    | Num of int
    | Label of string
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold 5 Zero = 5) true;
    assert_bool_equal (fold 5 (Num 1) = 5) true;
    assert_bool_equal (fold 5 (Label "kept") = 5) true
end

module Monomorphic_inline_record = struct
  type t =
    | Item of {
        count : int;
        label : string;
      }
    | Empty
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold 5 (Item { count = 1; label = "kept" }) = 5) true;
    assert_bool_equal (fold 5 Empty = 5) true
end

module Monomorphic_polyvariant = struct
  type t =
    [ `A
    | `B of int
    ]
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold 5 `A = 5) true;
    assert_bool_equal (fold 5 (`B 1) = 5) true
end

module Monomorphic_recursive = struct
  type t =
    | Leaf
    | Node of t * int
  [@@deriving fold]

  (* A payload of type t has no free type variables, so subtrees collapse to
     the accumulator passthrough instead of a recursive fold call. *)
  let run ~assert_bool_equal =
    let tree = Node (Node (Node (Leaf, 1), 2), 3) in
    assert_bool_equal (fold 5 tree = 5) true
end

module Monomorphic_container_aliases = struct
  type many = string list [@@deriving fold]
  type pair = int * bool [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold_many 5 [ "a"; "b" ] = 5) true;
    assert_bool_equal (fold_pair 5 (1, true) = 5) true
end

module Mixed_arity_group = struct
  (* A parameterized declaration and a zero-parameter one share the same
     let-rec group; both bindings carry their own polymorphic annotation. *)
  type 'a holder = H of 'a
  and box = int holder [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold_holder ( + ) 1 (H 2) = 3) true;
    assert_bool_equal (fold_box 5 (H 2) = 5) true
end

module Monomorphic_identity = struct
  module Plain = struct
    type t = T of int
  end

  type t = {
    name : string;
    plain : Plain.t;
    counts : int list;
  }
  [@@deriving fold]

  let run ~assert_bool_equal =
    (* Plain has no fold function: deriving must not require one for
       monomorphic fields, and the generated fold must pass the accumulator
       through. *)
    assert_bool_equal (fold 5 { name = "a"; plain = Plain.T 1; counts = [ 1; 2 ] } = 5) true
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving fold]
  end

  type 'a t = Boxed of 'a Box.t [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold ( + ) 1 (Boxed (Box.Box 7)) = 8) true
end

module Alias_of_generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving fold]
  end

  type 'a t = 'a Box.t [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold ( + ) 1 (Box.Box 7) = 8) true
end

module Result_alias = struct
  (* Mirrors the native fold test on a result alias with a callback per side
     and one shared accumulator. *)
  type ('a, 'b) t = ('a, 'b) result [@@deriving fold]

  let run ~assert_bool_equal =
    let f = fold ( + ) ( - ) 0 in
    assert_bool_equal (f (Ok 1) = 1) true;
    assert_bool_equal (f (Error 1) = -1) true
end

module Polymorphic_variant = struct
  type 'a t =
    [ `All
    | `Value of 'a
    | `Tagged of string
    ]
  [@@deriving fold]

  let run ~assert_bool_equal =
    assert_bool_equal (fold ( + ) 5 `All = 5) true;
    assert_bool_equal (fold ( + ) 5 (`Value 5) = 10) true;
    assert_bool_equal (fold ( + ) 5 (`Tagged "kept") = 5) true
end

module Recursive_polymorphic_variant = struct
  type ('a, 'b) t =
    [ `A of 'a
    | `B of ('a, 'b) t
    | `C of 'b
    ]
  [@@deriving fold]

  let run ~assert_bool_equal =
    let collect = fold (fun acc v -> acc ^ string_of_int v) (fun acc s -> acc ^ s) "" in
    assert_bool_equal (collect (`A 1) = "1") true;
    assert_bool_equal (collect (`B (`C "x")) = "x") true;
    assert_bool_equal (collect (`B (`B (`A 2))) = "2") true
end

module Status_naming = struct
  type 'a status = Active of 'a [@@deriving fold]

  let run ~assert_bool_equal = assert_bool_equal (fold_status ( + ) 1 (Active 4) = 5) true
end

module Module_signature = struct
  module M : sig
    type 'a t = Wrap of 'a [@@deriving fold]
  end = struct
    type 'a t = Wrap of 'a [@@deriving fold]
  end

  let run ~assert_bool_equal = assert_bool_equal (M.fold ( + ) 1 (M.Wrap 4) = 5) true
end

let all : Test_case.t list =
  [
    { name = "parameterized_variant"; run = Parameterized_variant.run };
    { name = "container_payloads"; run = Container_payloads.run };
    { name = "nested_containers"; run = Nested_containers.run };
    { name = "tuple_payload"; run = Tuple_payload.run };
    { name = "record_payload_constructor"; run = Record_payload_constructor.run };
    { name = "recursive_tree"; run = Recursive_tree.run };
    { name = "recursive_two_parameters"; run = Recursive_two_parameters.run };
    { name = "recursive_record_payload"; run = Recursive_record_payload.run };
    { name = "cross_type_record_payload"; run = Cross_type_record_payload.run };
    { name = "mutually_recursive"; run = Mutually_recursive.run };
    { name = "lexical_order"; run = Lexical_order.run };
    { name = "parameter_positions_only"; run = Parameter_positions_only.run };
    { name = "callback_call_count"; run = Callback_call_count.run };
    { name = "two_parameters"; run = Two_parameters.run };
    { name = "two_parameter_record"; run = Two_parameter_record.run };
    { name = "recursive_group_alias"; run = Recursive_group_alias.run };
    { name = "monomorphic_group_alias"; run = Monomorphic_group_alias.run };
    { name = "group_with_distinct_parameter_names"; run = Group_with_distinct_parameter_names.run };
    { name = "group_instantiating_sibling"; run = Group_instantiating_sibling.run };
    { name = "fragile_match_regression"; run = Fragile_match_regression.run };
    { name = "phantom_parameter"; run = Phantom_parameter.run };
    { name = "monomorphic_variant"; run = Monomorphic_variant.run };
    { name = "monomorphic_inline_record"; run = Monomorphic_inline_record.run };
    { name = "monomorphic_polyvariant"; run = Monomorphic_polyvariant.run };
    { name = "monomorphic_recursive"; run = Monomorphic_recursive.run };
    { name = "monomorphic_container_aliases"; run = Monomorphic_container_aliases.run };
    { name = "mixed_arity_group"; run = Mixed_arity_group.run };
    { name = "monomorphic_identity"; run = Monomorphic_identity.run };
    { name = "generic_application"; run = Generic_application.run };
    { name = "alias_of_generic_application"; run = Alias_of_generic_application.run };
    { name = "result_alias"; run = Result_alias.run };
    { name = "polymorphic_variant"; run = Polymorphic_variant.run };
    { name = "recursive_polymorphic_variant"; run = Recursive_polymorphic_variant.run };
    { name = "status_naming"; run = Status_naming.run };
    { name = "module_signature"; run = Module_signature.run };
  ]
