module Parameterized_variant = struct
  type 'a t =
    | Value of 'a
    | Pair of 'a * 'a
    | Fixed of string
    | Missing
  [@@deriving map]

  let run ~assert_bool_equal =
    let double = map (fun v -> v * 2) in
    assert_bool_equal (double (Value 1) = Value 2) true;
    assert_bool_equal (double (Pair (2, 3)) = Pair (4, 6)) true;
    assert_bool_equal (double (Fixed "kept") = Fixed "kept") true;
    assert_bool_equal (double Missing = Missing) true;
    assert_bool_equal (map string_of_int (Value 5) = Value "5") true
end

module Container_payloads = struct
  type 'a t = {
    items : 'a list;
    maybe : 'a option;
    scores : 'a array;
    outcome : ('a, 'a) result;
  }
  [@@deriving map]

  let run ~assert_bool_equal =
    let mapped = map string_of_int { items = [ 1; 2 ]; maybe = Some 3; scores = [| 4; 5 |]; outcome = Error 6 } in
    assert_bool_equal
      (mapped = { items = [ "1"; "2" ]; maybe = Some "3"; scores = [| "4"; "5" |]; outcome = Error "6" })
      true;
    let empty = map string_of_int { items = []; maybe = None; scores = [||]; outcome = Ok 9 } in
    assert_bool_equal (empty = { items = []; maybe = None; scores = [||]; outcome = Ok "9" }) true
end

module Nested_containers = struct
  type 'a t = Nested of 'a list option [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ (Nested (Some [ 1; 2 ])) = Nested (Some [ 2; 3 ])) true;
    assert_bool_equal (map succ (Nested None) = Nested None) true
end

module Tuple_payload = struct
  type 'a t = Pair of ('a * string) [@@deriving map]
  type 'a alias = 'a * string [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ (Pair (1, "kept")) = Pair (2, "kept")) true;
    assert_bool_equal (map_alias succ (2, "kept") = (3, "kept")) true
end

module Record_payload_constructor = struct
  type 'a t =
    | Empty
    | Item of {
        value : 'a;
        label : string;
        extras : 'a list;
      }
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ Empty = Empty) true;
    assert_bool_equal
      (map succ (Item { value = 1; label = "kept"; extras = [ 2; 3 ] })
      = Item { value = 2; label = "kept"; extras = [ 3; 4 ] })
      true
end

module Recursive_tree = struct
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving map]

  let run ~assert_bool_equal =
    let tree = Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)) in
    let expected = Node (Node (Leaf, 10, Leaf), 20, Node (Leaf, 30, Leaf)) in
    assert_bool_equal (map_tree (fun v -> v * 10) tree = expected) true
end

module Recursive_two_parameters = struct
  type ('a, 'b) t =
    | Left of 'a
    | Flag of bool
    | Chain of 'b * ('a, 'b) t
  [@@deriving map]

  let run ~assert_bool_equal =
    let convert = map succ String.uppercase_ascii in
    assert_bool_equal (convert (Chain ("abc", Chain ("xyz", Left 1))) = Chain ("ABC", Chain ("XYZ", Left 2))) true;
    assert_bool_equal (convert (Chain ("abc", Flag true)) = Chain ("ABC", Flag true)) true
end

module Recursive_record_payload = struct
  type 'a t =
    | Node of {
        left : 'a t;
        value : 'a;
        right : 'a t;
      }
    | Leaf
  [@@deriving map]

  let run ~assert_bool_equal =
    let tree = Node { left = Node { left = Leaf; value = 1; right = Leaf }; value = 2; right = Leaf } in
    let expected = Node { left = Node { left = Leaf; value = 10; right = Leaf }; value = 20; right = Leaf } in
    assert_bool_equal (map (fun v -> v * 10) tree = expected) true
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
  [@@deriving map]

  let run ~assert_bool_equal =
    let value =
      Group { rules = [ Rule { terms = [ "title" ]; search_location = 1 }; Rule { terms = []; search_location = 2 } ] }
    in
    let expected =
      Group
        { rules = [ Rule { terms = [ "title" ]; search_location = "1" }; Rule { terms = []; search_location = "2" } ] }
    in
    assert_bool_equal (map string_of_int value = expected) true
end

module Parameter_positions_only = struct
  type 'a t =
    | Value of 'a
    | Fixed of string
  [@@deriving map]

  (* map transforms values at type-parameter positions, not values of a
     matching type: instantiated at string, a Fixed payload must pass through
     untouched even though the callback could apply to it. *)
  let run ~assert_bool_equal =
    assert_bool_equal (map String.uppercase_ascii (Value "v") = Value "V") true;
    assert_bool_equal (map String.uppercase_ascii (Fixed "kept") = Fixed "kept") true
end

module Callback_call_count = struct
  type 'a t = {
    single : 'a;
    pair : 'a * 'a;
    items : 'a list;
    maybe : 'a option;
  }
  [@@deriving map]

  (* The callback runs exactly once per value at a parameter position: a
     double application or a skip would leave the count wrong even for
     idempotent callbacks. *)
  let run ~assert_bool_equal =
    let count = ref 0 in
    let mapped =
      map
        (fun v ->
          incr count;
          v)
        { single = 1; pair = 2, 3; items = [ 4; 5; 6 ]; maybe = Some 7 }
    in
    assert_bool_equal (!count = 7) true;
    assert_bool_equal (mapped = { single = 1; pair = 2, 3; items = [ 4; 5; 6 ]; maybe = Some 7 }) true
end

module Two_parameters = struct
  type ('a, 'b) t =
    | Left of 'a
    | Right of 'b
    | Both of 'a * 'b
  [@@deriving map]

  let run ~assert_bool_equal =
    let convert = map string_of_int String.uppercase_ascii in
    assert_bool_equal (convert (Left 1) = Left "1") true;
    assert_bool_equal (convert (Right "a") = Right "A") true;
    assert_bool_equal (convert (Both (2, "b")) = Both ("2", "B")) true
end

module Two_parameter_record = struct
  type ('a, 'b) t = {
    first : 'a;
    second : 'b;
  }
  [@@deriving map]

  (* Mirrors the native ppx_deriving regression test for issue #82: each field
     must be rebuilt by the callback matching its own type parameter. *)
  let run ~assert_bool_equal =
    assert_bool_equal
      (map string_of_int String.uppercase_ascii { first = 1; second = "x" } = { first = "1"; second = "X" })
      true
end

module Recursive_group_alias = struct
  type 'a pair = 'a * 'a
  and 'a t = 'a pair [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map succ (1, 2) = (2, 3)) true
end

module Monomorphic_group_alias = struct
  type a = A of int
  and b = a [@@deriving map]

  let run ~assert_bool_equal =
    (* map_b is the identity: it must exist and return its argument unchanged *)
    assert_bool_equal (map_b (A 1) = A 1) true
end

module Group_with_distinct_parameter_names = struct
  (* Regression: the generated let-rec annotations must quantify their type
     variables per binding. With group-scoped variables, u's 'b unified with
     t's 'a and 'b, silently collapsing map to ('a -> 'a) and rejecting
     type-changing calls like the one below. *)
  type 'a t = A of 'a
  and 'b u = B of 'b t [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map_u string_of_int (B (A 1)) = B (A "1")) true
end

module Group_instantiating_sibling = struct
  (* Regression: mapping a sibling instantiated at a composite argument
     requires polymorphic recursion across the group; with group-scoped
     annotation variables the generated code failed the occur check. *)
  type 'a t = A of 'a
  and 'a u = B of ('a * 'a) t [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map_u succ (B (A (1, 2))) = B (A (2, 3))) true
end

module Fragile_match_regression = struct
  [@@@ocaml.warning "@4"]

  type 'a t =
    | A
    | B of 'a
    | C of { x : 'a }
  [@@deriving map]

  type 'a pv =
    [ `A
    | `B of 'a
    ]
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ A = A) true;
    assert_bool_equal (map succ (B 1) = B 2) true;
    assert_bool_equal (map succ (C { x = 2 }) = C { x = 3 }) true;
    assert_bool_equal (map_pv succ `A = `A) true;
    assert_bool_equal (map_pv succ (`B 3) = `B 4) true
end

module Phantom_parameter = struct
  type 'a t = Id of int [@@deriving map]

  let run ~assert_bool_equal =
    let called = ref false in
    let mapped =
      map
        (fun _ ->
          called := true;
          ())
        (Id 1)
    in
    assert_bool_equal (mapped = Id 1) true;
    assert_bool_equal !called false
end

module Monomorphic_variant = struct
  type t =
    | Zero
    | Num of int
    | Label of string
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map Zero = Zero) true;
    assert_bool_equal (map (Num 1) = Num 1) true;
    assert_bool_equal (map (Label "kept") = Label "kept") true
end

module Monomorphic_inline_record = struct
  type t =
    | Item of {
        count : int;
        label : string;
      }
    | Empty
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map (Item { count = 1; label = "kept" }) = Item { count = 1; label = "kept" }) true;
    assert_bool_equal (map Empty = Empty) true
end

module Monomorphic_polyvariant = struct
  type t =
    [ `A
    | `B of int
    ]
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map `A = `A) true;
    assert_bool_equal (map (`B 1) = `B 1) true
end

module Monomorphic_recursive = struct
  type t =
    | Leaf
    | Node of t * int
  [@@deriving map]

  (* A payload of type t has no free type variables, so subtrees pass through
     the identity instead of a recursive map call; the whole structure must
     come back intact. *)
  let run ~assert_bool_equal =
    let tree = Node (Node (Node (Leaf, 1), 2), 3) in
    assert_bool_equal (map tree = tree) true
end

module Monomorphic_container_aliases = struct
  type many = string list [@@deriving map]
  type pair = int * bool [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map_many [ "a"; "b" ] = [ "a"; "b" ]) true;
    assert_bool_equal (map_pair (1, true) = (1, true)) true
end

module Mixed_arity_group = struct
  (* A parameterized declaration and a zero-parameter one share the same
     let-rec group: the first binding carries the polymorphic annotation, the
     second a plain monomorphic one. *)
  type 'a holder = H of 'a
  and box = int holder [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map_holder succ (H 1) = H 2) true;
    assert_bool_equal (map_box (H 5) = H 5) true
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
  [@@deriving map]

  let run ~assert_bool_equal =
    (* Plain has no map function: deriving must not require one for
       monomorphic fields, and the generated map must be the identity. *)
    let value = { name = "a"; plain = Plain.T 1; counts = [ 1; 2 ] } in
    assert_bool_equal (map value = value) true
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving map]
  end

  type 'a t = Boxed of 'a Box.t [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map succ (Boxed (Box.Box 7)) = Boxed (Box.Box 8)) true
end

module Alias_of_generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving map]
  end

  type 'a t = 'a Box.t [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map succ (Box.Box 7) = Box.Box 8) true
end

module Result_alias = struct
  type 'a t = ('a, bool) result [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ (Ok 9) = Ok 10) true;
    assert_bool_equal (map succ (Error true) = Error true) true
end

module Polymorphic_variant = struct
  type 'a t =
    [ `All
    | `Value of 'a
    | `Tagged of string
    ]
  [@@deriving map]

  let run ~assert_bool_equal =
    assert_bool_equal (map succ `All = `All) true;
    assert_bool_equal (map succ (`Value 5) = `Value 6) true;
    assert_bool_equal (map succ (`Tagged "kept") = `Tagged "kept") true
end

module Recursive_polymorphic_variant = struct
  type ('a, 'b) t =
    [ `A of 'a
    | `B of ('a, 'b) t
    | `C of 'b
    ]
  [@@deriving map]

  let run ~assert_bool_equal =
    let convert = map string_of_int String.uppercase_ascii in
    assert_bool_equal (convert (`A 1) = `A "1") true;
    assert_bool_equal (convert (`B (`C "x")) = `B (`C "X")) true;
    assert_bool_equal (convert (`B (`B (`A 2))) = `B (`B (`A "2"))) true
end

module Status_naming = struct
  type 'a status = Active of 'a [@@deriving map]

  let run ~assert_bool_equal = assert_bool_equal (map_status succ (Active 4) = Active 5) true
end

module Module_signature = struct
  module M : sig
    type 'a t = Wrap of 'a [@@deriving map]
  end = struct
    type 'a t = Wrap of 'a [@@deriving map]
  end

  let run ~assert_bool_equal = assert_bool_equal (M.map succ (M.Wrap 4) = M.Wrap 5) true
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
    { name = "mutually_recursive"; run = Mutually_recursive.run };
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
