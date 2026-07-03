module Variant_printing = struct
  type t =
    | Zero
    | One of int
    | Pair of int * string
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show Zero) "Zero") true;
    assert_bool_equal (String.equal (show (One 5)) "(One 5)") true;
    assert_bool_equal (String.equal (show (Pair (1, "a"))) {|(Pair (1, "a"))|}) true
end

module With_path_default = struct
  type t = Red [@@deriving show]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show Red) "Test_show_cases.With_path_default.Red") true
end

module Record_printing = struct
  type t = {
    name : string;
    count : int;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show { name = "a"; count = 1 }) {|{ name = "a"; count = 1 }|}) true
end

module Inline_record = struct
  type t =
    | Empty
    | Item of {
        rank : int;
        label : string;
      }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show Empty) "Empty") true;
    assert_bool_equal (String.equal (show (Item { rank = 1; label = "x" })) {|Item {rank = 1; label = "x"}|}) true
end

module Primitives = struct
  (* Two records instead of one: past Format's default 80-column margin the
     break hints would render as newlines. *)
  type text = {
    s : string;
    f : float;
    c : char;
    b : bool;
  }
  [@@deriving show { with_path = false }]

  type numbers = {
    i32 : int32;
    i64 : int64;
    raw : bytes;
    nothing : unit;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal
      (String.equal (show_text { s = "a"; f = 1.5; c = 'z'; b = true }) {|{ s = "a"; f = 1.5; c = 'z'; b = true }|})
      true;
    assert_bool_equal
      (String.equal
         (show_numbers { i32 = 7l; i64 = 9L; raw = Bytes.of_string "hi"; nothing = () })
         {|{ i32 = 7l; i64 = 9L; raw = "hi"; nothing = () }|})
      true
end

module String_escaping = struct
  type str = string [@@deriving show]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_str {|a"b|}) {|"a\"b"|}) true;
    assert_bool_equal (String.equal (show_str "a\nb") {|"a\nb"|}) true
end

module Containers = struct
  type t = {
    items : int list;
    maybe : int option;
    scores : int array;
    outcome : (int, string) result;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    let value = { items = [ 1; 2 ]; maybe = Some 1; scores = [| 3 |]; outcome = Ok 1 } in
    assert_bool_equal
      (String.equal (show value) {|{ items = [1; 2]; maybe = (Some 1); scores = [|3|]; outcome = (Ok 1) }|})
      true;
    let value = { items = []; maybe = None; scores = [||]; outcome = Error "e" } in
    assert_bool_equal
      (String.equal (show value) {|{ items = []; maybe = None; scores = [||]; outcome = (Error "e") }|})
      true
end

module Tuple_alias = struct
  type t = int * string [@@deriving show]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show (1, "a")) {|(1, "a")|}) true
end

module Two_parameters = struct
  type ('a, 'b) t = {
    first : 'a;
    second : 'b;
  }
  [@@deriving show { with_path = false }]

  let int_printer fmt (x : int) = Stdlib.Format.fprintf fmt "%d" x
  let string_printer fmt (x : string) = Stdlib.Format.fprintf fmt "%S" x

  let run ~assert_bool_equal =
    assert_bool_equal
      (String.equal (show int_printer string_printer { first = 1; second = "b" }) {|{ first = 1; second = "b" }|})
      true
end

module Parameterized = struct
  type 'a t =
    | Value of 'a
    | Missing
  [@@deriving show { with_path = false }]

  let int_printer fmt (x : int) = Stdlib.Format.fprintf fmt "%d" x

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show int_printer (Value 1)) "(Value 1)") true;
    assert_bool_equal (String.equal (show int_printer Missing) "Missing") true
end

module Recursive_tree = struct
  type 'a tree =
    | Leaf
    | Node of 'a tree * 'a * 'a tree
  [@@deriving show { with_path = false }]

  let int_printer fmt (x : int) = Stdlib.Format.fprintf fmt "%d" x

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_tree int_printer (Node (Leaf, 1, Leaf))) "(Node (Leaf, 1, Leaf))") true
end

module Mutual_recursion = struct
  type tree =
    | Leaf of int
    | Node of forest

  and forest = { trees : tree list } [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_tree (Node { trees = [ Leaf 1 ] })) {|(Node { trees = [(Leaf 1)] })|}) true;
    assert_bool_equal (String.equal (show_forest { trees = [] }) {|{ trees = [] }|}) true
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving show { with_path = false }]
  end

  type t = Boxed of int Box.t [@@deriving show { with_path = false }]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show (Boxed (Box.Box 1))) "(Boxed (Box 1))") true
end

module Polymorphic_variant = struct
  type t =
    [ `All
    | `Name of string
    | `Count of int
    ]
  [@@deriving show]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show `All) "`All") true;
    assert_bool_equal (String.equal (show (`Name "a")) {|`Name ("a")|}) true;
    assert_bool_equal (String.equal (show (`Count 1)) "`Count (1)") true
end

module Custom_printer = struct
  type t = Named of (string[@printer fun fmt -> fprintf fmt "name=%s"]) [@@deriving show { with_path = false }]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show (Named "x")) "(Named name=x)") true
end

module Namespaced_custom_printer = struct
  type t = { at : (float[@deriving.show.printer fun fmt x -> Stdlib.Format.fprintf fmt "%.2f" x]) }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show { at = 1.5 }) "{ at = 1.50 }") true
end

module Opaque_and_functions = struct
  type t = {
    secret : (string[@opaque]);
    callback : int -> unit;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal
      (String.equal (show { secret = "s"; callback = (fun _n -> ()) }) "{ secret = <opaque>; callback = <fun> }")
      true
end

module Pp_show_consistency = struct
  type t = {
    name : string;
    count : int;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    let value = { name = "a"; count = 1 } in
    assert_bool_equal (String.equal (Stdlib.Format.asprintf "%a" pp value) (show value)) true
end

module Status_naming = struct
  type status =
    | Active
    | Inactive
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_status Active) "Active") true;
    assert_bool_equal (String.equal (show_status Inactive) "Inactive") true
end

module Float_edge_cases = struct
  type fl = float [@@deriving show]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_fl 1.0) "1.") true;
    assert_bool_equal (String.equal (show_fl 1.5) "1.5") true;
    assert_bool_equal (String.equal (show_fl infinity) "infinity") true;
    assert_bool_equal (String.equal (show_fl nan) "nan") true;
    assert_bool_equal (String.equal (show_fl 1e21) "1e+21") true
end

module Poly_variant_tuple_payload = struct
  type t =
    [ `Foo
    | `Bar of int * string
    ]
  [@@deriving show]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show `Foo) "`Foo") true;
    assert_bool_equal (String.equal (show (`Bar (1, "foo"))) {|`Bar ((1, "foo"))|}) true
end

module Variant_nested_option = struct
  type t = Foo of int option [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show (Foo (Some 1))) "(Foo (Some 1))") true;
    assert_bool_equal (String.equal (show (Foo None)) "(Foo None)") true
end

module Mutual_recursion_parameterized = struct
  type foo =
    | F of int
    | B of int bar

  and 'a bar = {
    x : 'a;
    r : foo;
  }
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_foo (B { x = 12; r = F 16 })) "(B { x = 12; r = (F 16) })") true
end

module Alias_to_type_variable = struct
  type poly_app = float poly_abs
  and 'a poly_abs = 'a [@@deriving show]

  let run ~assert_bool_equal = assert_bool_equal (String.equal (show_poly_app 1.0) "1.") true
end

module Stdlib_module_shadowing = struct
  module List = struct
    type 'a t =
      [ `Cons of 'a
      | `Nil
      ]
    [@@deriving show]
  end

  type 'a std_clash = 'a List.t option [@@deriving show]

  let int_printer fmt (x : int) = Stdlib.Format.fprintf fmt "%d" x

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show_std_clash int_printer (Some (`Cons 1))) {|(Some `Cons (1))|}) true;
    assert_bool_equal (String.equal (show_std_clash int_printer (Some `Nil)) "(Some `Nil)") true
end

module Re_export_path = struct
  module M = struct
    type t = A [@@deriving show { with_path = false }]
  end

  module M' = struct
    type t = M.t = A [@@deriving show]
  end

  (* a bare alias delegates to M.pp: an eta-expanded reference, not a lambda *)
  type z = M.t [@@deriving show]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (M'.show M'.A) "M.A") true;
    assert_bool_equal (String.equal (show_z M.A) "A") true
end

module Constructor_printer = struct
  type t =
    | First [@printer fun fmt _ -> Format.pp_print_string fmt "first"]
    | Second of int [@printer fun fmt i -> fprintf fmt "second: %d" i]
    | Third
    | Fourth of int * int [@printer fun fmt (a, b) -> fprintf fmt "fourth: %d %d" a b]
    | Fifth of {
        x : int;
        y : string;
      } [@printer fun fmt x y -> fprintf fmt "fifth: %d %s" x y]
  [@@deriving show { with_path = false }]

  let run ~assert_bool_equal =
    assert_bool_equal (String.equal (show First) "first") true;
    assert_bool_equal (String.equal (show (Second 42)) "second: 42") true;
    assert_bool_equal (String.equal (show Third) "Third") true;
    assert_bool_equal (String.equal (show (Fourth (8, 4))) "fourth: 8 4") true;
    assert_bool_equal (String.equal (show (Fifth { x = 1; y = "a" })) "fifth: 1 a") true
end

module Module_signature = struct
  module M : sig
    type t =
      | A
      | B
    [@@deriving show { with_path = false }]
  end = struct
    type t =
      | A
      | B
    [@@deriving show { with_path = false }]
  end

  let run ~assert_bool_equal = assert_bool_equal (String.equal (M.show M.A) "A") true
end

let all : Test_case.t list =
  [
    { name = "variant_printing"; run = Variant_printing.run };
    { name = "with_path_default"; run = With_path_default.run };
    { name = "record_printing"; run = Record_printing.run };
    { name = "inline_record"; run = Inline_record.run };
    { name = "primitives"; run = Primitives.run };
    { name = "string_escaping"; run = String_escaping.run };
    { name = "containers"; run = Containers.run };
    { name = "tuple_alias"; run = Tuple_alias.run };
    { name = "two_parameters"; run = Two_parameters.run };
    { name = "parameterized"; run = Parameterized.run };
    { name = "recursive_tree"; run = Recursive_tree.run };
    { name = "mutual_recursion"; run = Mutual_recursion.run };
    { name = "generic_application"; run = Generic_application.run };
    { name = "polymorphic_variant"; run = Polymorphic_variant.run };
    { name = "custom_printer"; run = Custom_printer.run };
    { name = "namespaced_custom_printer"; run = Namespaced_custom_printer.run };
    { name = "opaque_and_functions"; run = Opaque_and_functions.run };
    { name = "pp_show_consistency"; run = Pp_show_consistency.run };
    { name = "status_naming"; run = Status_naming.run };
    { name = "float_edge_cases"; run = Float_edge_cases.run };
    { name = "poly_variant_tuple_payload"; run = Poly_variant_tuple_payload.run };
    { name = "variant_nested_option"; run = Variant_nested_option.run };
    { name = "mutual_recursion_parameterized"; run = Mutual_recursion_parameterized.run };
    { name = "alias_to_type_variable"; run = Alias_to_type_variable.run };
    { name = "stdlib_module_shadowing"; run = Stdlib_module_shadowing.run };
    { name = "re_export_path"; run = Re_export_path.run };
    { name = "constructor_printer"; run = Constructor_printer.run };
    { name = "module_signature"; run = Module_signature.run };
  ]
