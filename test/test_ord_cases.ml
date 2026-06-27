module Variant_ordering = struct
  type t =
    | Red
    | Green
    | Blue
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare Red Red = 0) true;
    assert_bool_equal (compare Red Green < 0) true;
    assert_bool_equal (compare Blue Green > 0) true
end

module Payload_tiebreak = struct
  type t = Pair of int * string [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare (Pair (1, "a")) (Pair (1, "a")) = 0) true;
    assert_bool_equal (compare (Pair (1, "a")) (Pair (1, "b")) < 0) true;
    assert_bool_equal (compare (Pair (1, "b")) (Pair (2, "a")) < 0) true
end

module Record_lexicographic = struct
  type t = {
    name : string;
    count : int;
  }
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare { name = "a"; count = 1 } { name = "a"; count = 1 } = 0) true;
    assert_bool_equal (compare { name = "a"; count = 1 } { name = "a"; count = 2 } < 0) true;
    assert_bool_equal (compare { name = "b"; count = 1 } { name = "a"; count = 9 } > 0) true
end

module Inline_record = struct
  type t =
    | Empty
    | Item of {
        rank : int;
        label : string;
      }
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare Empty (Item { rank = 1; label = "x" }) < 0) true;
    assert_bool_equal (compare (Item { rank = 1; label = "a" }) (Item { rank = 1; label = "b" }) < 0) true
end

module Unit_field = struct
  type t = {
    tag : unit;
    n : int;
  }
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare { tag = (); n = 1 } { tag = (); n = 1 } = 0) true;
    assert_bool_equal (compare { tag = (); n = 1 } { tag = (); n = 2 } < 0) true
end

module Containers = struct
  type t = {
    items : int list;
    maybe : int option;
    scores : int array;
    outcome : (int, string) result;
  }
  [@@deriving ord]

  let base = { items = [ 1; 2 ]; maybe = Some 1; scores = [| 1 |]; outcome = Ok 1 }

  let run ~assert_bool_equal =
    assert_bool_equal (compare base base = 0) true;
    assert_bool_equal (compare { base with items = [ 1 ] } base < 0) true;
    assert_bool_equal (compare { base with maybe = None } base < 0) true;
    assert_bool_equal (compare { base with outcome = Error "e" } base > 0) true
end

module Container_ordering = struct
  type ints = int list [@@deriving ord]
  type int_array = int array [@@deriving ord]
  type int_option = int option [@@deriving ord]
  type int_result = (int, string) result [@@deriving ord]

  let run ~assert_bool_equal =
    (* list is lexicographic: a prefix is smaller, but elements decide before length *)
    assert_bool_equal (compare_ints [ 1 ] [ 1; 2 ] < 0) true;
    assert_bool_equal (compare_ints [ 1; 2 ] [ 1 ] > 0) true;
    assert_bool_equal (compare_ints [ 2 ] [ 1; 9 ] > 0) true;
    assert_bool_equal (compare_ints [ 1; 9 ] [ 2 ] < 0) true;
    (* array compares length first, then elements (note: differs from list) *)
    assert_bool_equal (compare_int_array [| 2 |] [| 1; 9 |] < 0) true;
    assert_bool_equal (compare_int_array [| 1; 2 |] [| 1; 3 |] < 0) true;
    assert_bool_equal (compare_int_array [| 1; 3 |] [| 1; 2 |] > 0) true;
    (* option: None < Some, and the payload is compared *)
    assert_bool_equal (compare_int_option None (Some 0) < 0) true;
    assert_bool_equal (compare_int_option (Some 0) None > 0) true;
    assert_bool_equal (compare_int_option (Some 1) (Some 2) < 0) true;
    (* result: Ok < Error, and each side's payload is compared *)
    assert_bool_equal (compare_int_result (Ok 1) (Error "e") < 0) true;
    assert_bool_equal (compare_int_result (Error "e") (Ok 1) > 0) true;
    assert_bool_equal (compare_int_result (Ok 1) (Ok 2) < 0) true;
    assert_bool_equal (compare_int_result (Error "a") (Error "b") < 0) true
end

module Two_parameters = struct
  type ('a, 'b) t = {
    first : 'a;
    second : 'b;
  }
  [@@deriving ord]

  let int_compare (a : int) b = Stdlib.compare a b
  let string_compare (a : string) b = Stdlib.compare a b

  let run ~assert_bool_equal =
    let compare = compare int_compare string_compare in
    assert_bool_equal (compare { first = 1; second = "b" } { first = 1; second = "b" } = 0) true;
    (* second parameter breaks ties on the first *)
    assert_bool_equal (compare { first = 1; second = "a" } { first = 1; second = "b" } < 0) true;
    (* first parameter dominates the second *)
    assert_bool_equal (compare { first = 1; second = "z" } { first = 2; second = "a" } < 0) true;
    assert_bool_equal (compare { first = 2; second = "a" } { first = 1; second = "z" } > 0) true
end

module Tuple_alias = struct
  type t = int * string [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare (1, "a") (1, "a") = 0) true;
    assert_bool_equal (compare (1, "a") (1, "b") < 0) true;
    assert_bool_equal (compare (2, "a") (1, "z") > 0) true
end

module Recursive_tree = struct
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving ord]

  let leaf v = Node (Leaf, v, Leaf)

  let run ~assert_bool_equal =
    assert_bool_equal (compare_tree Stdlib.compare (leaf 1) (leaf 1) = 0) true;
    assert_bool_equal (compare_tree Stdlib.compare (leaf 1) (leaf 2) < 0) true;
    assert_bool_equal (compare_tree Stdlib.compare Leaf (leaf 1) < 0) true
end

module Parameterized = struct
  type 'a t =
    | Value of 'a
    | Missing
  [@@deriving ord]

  let int_compare (a : int) b = Stdlib.compare a b

  let run ~assert_bool_equal =
    assert_bool_equal (compare int_compare (Value 1) (Value 1) = 0) true;
    assert_bool_equal (compare int_compare (Value 1) (Value 2) < 0) true;
    assert_bool_equal (compare int_compare Missing (Value 1) > 0) true
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving ord]
  end

  type t = Boxed of int Box.t [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare (Boxed (Box.Box 1)) (Boxed (Box.Box 1)) = 0) true;
    assert_bool_equal (compare (Boxed (Box.Box 1)) (Boxed (Box.Box 2)) < 0) true
end

module Polymorphic_variant = struct
  type t =
    [ `All
    | `Name of string
    | `Count of int
    ]
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare `All `All = 0) true;
    assert_bool_equal (compare `All (`Name "x") < 0) true;
    assert_bool_equal (compare (`Name "a") (`Name "b") < 0) true
end

module Custom_compare = struct
  type t = ByLength of (string[@compare fun a b -> Stdlib.compare (String.length a) (String.length b)])
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare (ByLength "a") (ByLength "b") = 0) true;
    assert_bool_equal (compare (ByLength "a") (ByLength "bb") < 0) true
end

module Status_naming = struct
  type status =
    | Active
    | Inactive
  [@@deriving ord]

  let run ~assert_bool_equal =
    assert_bool_equal (compare_status Active Active = 0) true;
    assert_bool_equal (compare_status Active Inactive < 0) true
end

module Module_signature = struct
  module M : sig
    type t =
      | A
      | B
    [@@deriving ord]
  end = struct
    type t =
      | A
      | B
    [@@deriving ord]
  end

  let run ~assert_bool_equal =
    assert_bool_equal (M.compare M.A M.A = 0) true;
    assert_bool_equal (M.compare M.A M.B < 0) true
end

let all : Test_case.t list =
  [
    { name = "variant_ordering"; run = Variant_ordering.run };
    { name = "payload_tiebreak"; run = Payload_tiebreak.run };
    { name = "record_lexicographic"; run = Record_lexicographic.run };
    { name = "inline_record"; run = Inline_record.run };
    { name = "unit_field"; run = Unit_field.run };
    { name = "containers"; run = Containers.run };
    { name = "container_ordering"; run = Container_ordering.run };
    { name = "two_parameters"; run = Two_parameters.run };
    { name = "tuple_alias"; run = Tuple_alias.run };
    { name = "recursive_tree"; run = Recursive_tree.run };
    { name = "parameterized"; run = Parameterized.run };
    { name = "generic_application"; run = Generic_application.run };
    { name = "polymorphic_variant"; run = Polymorphic_variant.run };
    { name = "custom_compare"; run = Custom_compare.run };
    { name = "status_naming"; run = Status_naming.run };
    { name = "module_signature"; run = Module_signature.run };
  ]
