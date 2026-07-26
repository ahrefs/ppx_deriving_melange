module Variant = struct
  type t =
    | First
    | Second
    | Third
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal First First) true;
    assert_bool_equal (equal First Second) false;
    assert_bool_equal (equal Third Third) true
end

module Variant_payload = struct
  type t =
    | Latest
    | Date of string
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal Latest Latest) true;
    assert_bool_equal (equal (Date "2026-06-05") (Date "2026-06-05")) true;
    assert_bool_equal (equal (Date "2026-06-05") (Date "2026-06-06")) false;
    assert_bool_equal (equal Latest (Date "2026-06-05")) false
end

module Primitive_payloads = struct
  type t =
    | StringPayload of string
    | IntPayload of int
    | BoolPayload of bool
    | FloatPayload of float
    | CharPayload of char
    | BytesPayload of bytes
    | Int32Payload of int32
    | QualifiedInt32Payload of Int32.t
    | Int64Payload of int64
    | QualifiedInt64Payload of Int64.t
    | UnitPayload of unit
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (UnitPayload ()) (UnitPayload ())) true;
    assert_bool_equal (equal (StringPayload "a") (StringPayload "a")) true;
    assert_bool_equal (equal (IntPayload 1) (IntPayload 1)) true;
    assert_bool_equal (equal (BoolPayload true) (BoolPayload true)) true;
    assert_bool_equal (equal (FloatPayload 1.5) (FloatPayload 1.5)) true;
    assert_bool_equal (equal (CharPayload 'a') (CharPayload 'a')) true;
    assert_bool_equal (equal (BytesPayload (Bytes.of_string "a")) (BytesPayload (Bytes.of_string "a"))) true;
    assert_bool_equal (equal (Int32Payload 1l) (Int32Payload 1l)) true;
    assert_bool_equal (equal (QualifiedInt32Payload 1l) (QualifiedInt32Payload 1l)) true;
    assert_bool_equal (equal (Int64Payload 1L) (Int64Payload 1L)) true;
    assert_bool_equal (equal (QualifiedInt64Payload 1L) (QualifiedInt64Payload 1L)) true;
    assert_bool_equal (equal (IntPayload 1) (IntPayload 2)) false
end

module Primitive_aliases = struct
  type string_alias = string [@@deriving eq]
  type int_alias = int [@@deriving eq]
  type bool_alias = bool [@@deriving eq]
  type float_alias = float [@@deriving eq]
  type char_alias = char [@@deriving eq]
  type bytes_alias = bytes [@@deriving eq]
  type int32_alias = int32 [@@deriving eq]
  type qualified_int32_alias = Int32.t [@@deriving eq]
  type int64_alias = int64 [@@deriving eq]
  type qualified_int64_alias = Int64.t [@@deriving eq]
  type unit_alias = unit [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal_unit_alias () ()) true;
    assert_bool_equal (equal_string_alias "a" "a") true;
    assert_bool_equal (equal_int_alias 1 1) true;
    assert_bool_equal (equal_bool_alias true true) true;
    assert_bool_equal (equal_float_alias 1.5 1.5) true;
    assert_bool_equal (equal_char_alias 'a' 'a') true;
    assert_bool_equal (equal_bytes_alias (Bytes.of_string "a") (Bytes.of_string "a")) true;
    assert_bool_equal (equal_int32_alias 1l 1l) true;
    assert_bool_equal (equal_qualified_int32_alias 1l 1l) true;
    assert_bool_equal (equal_int64_alias 1L 1L) true;
    assert_bool_equal (equal_qualified_int64_alias 1L 1L) true;
    assert_bool_equal (equal_int_alias 1 2) false
end

module Custom_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t = CustomPayload of Custom.t [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (CustomPayload (Custom.T 1)) (CustomPayload (Custom.T 1))) true;
    assert_bool_equal (equal (CustomPayload (Custom.T 1)) (CustomPayload (Custom.T 2))) false
end

module Custom_attribute_payload = struct
  type t = ByLength of (string[@equal fun a b -> String.length a = String.length b]) [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (ByLength "a") (ByLength "b")) true;
    assert_bool_equal (equal (ByLength "a") (ByLength "bb")) false
end

module List_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t =
    | Strings of string list
    | CustomItems of Custom.t list
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (Strings [ "a"; "b" ]) (Strings [ "a"; "b" ])) true;
    assert_bool_equal (equal (Strings [ "a"; "b" ]) (Strings [ "b"; "a" ])) false;
    assert_bool_equal (equal (Strings [ "a" ]) (Strings [ "a"; "b" ])) false;
    assert_bool_equal (equal (CustomItems [ Custom.T 1; Custom.T 2 ]) (CustomItems [ Custom.T 1; Custom.T 2 ])) true;
    assert_bool_equal (equal (CustomItems [ Custom.T 1 ]) (CustomItems [ Custom.T 2 ])) false
end

module Option_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t =
    | MaybeString of string option
    | MaybeCustom of Custom.t option
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (MaybeString None) (MaybeString None)) true;
    assert_bool_equal (equal (MaybeString (Some "a")) (MaybeString (Some "a"))) true;
    assert_bool_equal (equal (MaybeString (Some "a")) (MaybeString (Some "b"))) false;
    assert_bool_equal (equal (MaybeString None) (MaybeString (Some "a"))) false;
    assert_bool_equal (equal (MaybeCustom (Some (Custom.T 1))) (MaybeCustom (Some (Custom.T 1)))) true;
    assert_bool_equal (equal (MaybeCustom (Some (Custom.T 1))) (MaybeCustom (Some (Custom.T 2)))) false
end

module Array_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t =
    | Strings of string array
    | CustomItems of Custom.t array
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (Strings [| "a"; "b" |]) (Strings [| "a"; "b" |])) true;
    assert_bool_equal (equal (Strings [| "a"; "b" |]) (Strings [| "b"; "a" |])) false;
    assert_bool_equal (equal (Strings [| "a" |]) (Strings [| "a"; "b" |])) false;
    assert_bool_equal (equal (CustomItems [| Custom.T 1; Custom.T 2 |]) (CustomItems [| Custom.T 1; Custom.T 2 |])) true;
    assert_bool_equal (equal (CustomItems [| Custom.T 1 |]) (CustomItems [| Custom.T 2 |])) false
end

module Result_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t =
    | ResultValue of (string, int) result
    | CustomResultValue of (Custom.t, string) result
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (ResultValue (Ok "a")) (ResultValue (Ok "a"))) true;
    assert_bool_equal (equal (ResultValue (Ok "a")) (ResultValue (Ok "b"))) false;
    assert_bool_equal (equal (ResultValue (Error 1)) (ResultValue (Error 1))) true;
    assert_bool_equal (equal (ResultValue (Error 1)) (ResultValue (Error 2))) false;
    assert_bool_equal (equal (ResultValue (Ok "a")) (ResultValue (Error 1))) false;
    assert_bool_equal (equal (CustomResultValue (Ok (Custom.T 1))) (CustomResultValue (Ok (Custom.T 1)))) true;
    assert_bool_equal (equal (CustomResultValue (Ok (Custom.T 1))) (CustomResultValue (Ok (Custom.T 2)))) false
end

module Tuple_payload = struct
  module Custom = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type t =
    | Pair of (int * string)
    | CustomPair of (Custom.t * string)
  [@@deriving eq]

  type alias = int * string [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (Pair (1, "a")) (Pair (1, "a"))) true;
    assert_bool_equal (equal (Pair (1, "a")) (Pair (2, "a"))) false;
    assert_bool_equal (equal (Pair (1, "a")) (Pair (1, "b"))) false;
    assert_bool_equal (equal (CustomPair (Custom.T 1, "a")) (CustomPair (Custom.T 1, "a"))) true;
    assert_bool_equal (equal (CustomPair (Custom.T 1, "a")) (CustomPair (Custom.T 2, "a"))) false;
    assert_bool_equal (equal_alias (1, "a") (1, "a")) true;
    assert_bool_equal (equal_alias (1, "a") (1, "b")) false
end

module Polymorphic_variant = struct
  type t =
    [ `All
    | `Name of string
    | `Count of int
    ]
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal `All `All) true;
    assert_bool_equal (equal (`Name "a") (`Name "a")) true;
    assert_bool_equal (equal (`Name "a") (`Name "b")) false;
    assert_bool_equal (equal (`Name "a") (`Count 1)) false
end

module Type_alias = struct
  type source =
    | AliasA
    | AliasB
  [@@deriving eq]

  type t = source [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal AliasA AliasA) true;
    assert_bool_equal (equal AliasA AliasB) false
end

module Type_t = struct
  type t =
    | One
    | Two
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal One One) true;
    assert_bool_equal (equal One Two) false
end

module Module_signature = struct
  module M : sig
    type t =
      | A
      | B
    [@@deriving eq]
  end = struct
    type t =
      | A
      | B
    [@@deriving eq]
  end

  let run ~assert_bool_equal =
    assert_bool_equal (M.equal M.A M.A) true;
    assert_bool_equal (M.equal M.A M.B) false
end

module Type_t_alias = struct
  type source =
    | AliasA
    | AliasB
  [@@deriving eq]

  module M : sig
    type t = source [@@deriving eq]
  end = struct
    type t = source [@@deriving eq]
  end

  let run ~assert_bool_equal =
    assert_bool_equal (M.equal AliasA AliasA) true;
    assert_bool_equal (M.equal AliasA AliasB) false
end

module Record_type = struct
  module Mode = struct
    type t =
      | Exact
      | Prefix
    [@@deriving eq]
  end

  type t = {
    name : string;
    count : int;
    mode : Mode.t;
    description : string option;
  }
  [@@deriving eq]

  let base = { name = "brand"; count = 1; mode = Mode.Exact; description = Some "desc" }

  let run ~assert_bool_equal =
    assert_bool_equal (equal base base) true;
    assert_bool_equal (equal base { base with count = 2 }) false;
    assert_bool_equal (equal base { base with mode = Mode.Prefix }) false;
    assert_bool_equal (equal base { base with description = None }) false
end

module Record_payload_constructor = struct
  module Mode = struct
    type t =
      | Exact
      | Prefix
    [@@deriving eq]
  end

  type t =
    | Empty
    | Item of {
        name : string;
        count : int;
        mode : Mode.t;
      }
  [@@deriving eq]

  let item mode = Item { name = "brand"; count = 1; mode }

  let run ~assert_bool_equal =
    assert_bool_equal (equal Empty Empty) true;
    assert_bool_equal (equal (item Mode.Exact) (item Mode.Exact)) true;
    assert_bool_equal (equal (item Mode.Exact) (Item { name = "other"; count = 1; mode = Mode.Exact })) false;
    assert_bool_equal (equal (item Mode.Exact) (Item { name = "brand"; count = 2; mode = Mode.Exact })) false;
    assert_bool_equal (equal (item Mode.Exact) (item Mode.Prefix)) false;
    assert_bool_equal (equal Empty (item Mode.Exact)) false
end

module Record_field_custom_equal = struct
  let equal_unordered_string_list a b = List.sort String.compare a = List.sort String.compare b

  type t = {
    urls_groups : string list; [@equal equal_unordered_string_list]
    name : string;
  }
  [@@deriving eq]

  let base = { urls_groups = [ "b"; "a" ]; name = "brand" }

  let run ~assert_bool_equal =
    assert_bool_equal (equal base { base with urls_groups = [ "a"; "b" ] }) true;
    assert_bool_equal (equal base { base with urls_groups = [ "a"; "c" ] }) false;
    assert_bool_equal (equal base { base with name = "other" }) false
end

module Tag_like_record = struct
  module TagId = struct
    type t = T of int

    let equal (T a) (T b) = a = b
  end

  type state =
    | Saved of TagId.t
    | Unsaved of string
  [@@deriving eq]

  type t = {
    state : state;
    name : string;
  }
  [@@deriving eq]

  let saved = { state = Saved (TagId.T 1); name = "Tag" }

  let run ~assert_bool_equal =
    assert_bool_equal (equal saved saved) true;
    assert_bool_equal (equal saved { saved with state = Saved (TagId.T 2) }) false;
    assert_bool_equal (equal saved { saved with name = "Other" }) false
end

module Parameterized_variant = struct
  type 'a t =
    | Value of 'a
    | Missing
  [@@deriving eq]

  let int_equal (a : int) b = a = b

  let run ~assert_bool_equal =
    assert_bool_equal (equal int_equal (Value 1) (Value 1)) true;
    assert_bool_equal (equal int_equal (Value 1) (Value 2)) false;
    assert_bool_equal (equal int_equal Missing Missing) true
end

module Phantom_parameter = struct
  type 'a t = Id of int [@@deriving eq]

  let int_equal (a : int) b = a = b

  let run ~assert_bool_equal =
    assert_bool_equal (equal int_equal (Id 1) (Id 1)) true;
    assert_bool_equal (equal int_equal (Id 1) (Id 2)) false
end

module Generic_application = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving eq]
  end

  module Item = struct
    type t =
      | A
      | B
    [@@deriving eq]
  end

  type t = Item.t Box.t [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (Box Item.A) (Box Item.A)) true;
    assert_bool_equal (equal (Box Item.A) (Box Item.B)) false
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
  [@@deriving eq]

  let string_equal (a : string) b = a = b

  let rule search_location terms = Rule { terms; search_location }

  let run ~assert_bool_equal =
    let value = Group { rules = [ rule "title" [ "a" ]; rule "url" [ "b" ] ] } in
    let changed_term = Group { rules = [ rule "title" [ "a" ]; rule "url" [ "c" ] ] } in
    let changed_location = Group { rules = [ rule "title" [ "a" ]; rule "content" [ "b" ] ] } in
    assert_bool_equal (equal string_equal value value) true;
    assert_bool_equal (equal string_equal value changed_term) false;
    assert_bool_equal (equal string_equal value changed_location) false
end

module Alias_to_type_variable = struct
  type poly_app = float poly_abs
  and 'a poly_abs = 'a [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal_poly_app 1.0 1.0) true;
    assert_bool_equal (equal_poly_app 1.0 2.0) false
end

module Recursive_group_alias = struct
  type a =
    | A
    | B

  and b = a [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal_b A A) true;
    assert_bool_equal (equal_b A B) false
end

module Generic_application_alias = struct
  module Box = struct
    type 'a t = Box of 'a [@@deriving eq]
  end

  module Item = struct
    type t =
      | A
      | B
    [@@deriving eq]
  end

  type t = Item.t Box.t [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal (Box.Box Item.A) (Box.Box Item.A)) true;
    assert_bool_equal (equal (Box.Box Item.A) (Box.Box Item.B)) false
end

module Fragile_match_regression = struct
  [@@@ocaml.warning "@4"]

  type t =
    | A
    | B of int
    | C of { x : int }
  [@@deriving eq]

  type pv =
    [ `A
    | `B of int
    ]
  [@@deriving eq]

  let run ~assert_bool_equal =
    assert_bool_equal (equal A A) true;
    assert_bool_equal (equal A (B 1)) false;
    assert_bool_equal (equal (B 1) (C { x = 1 })) false;
    assert_bool_equal (equal_pv `A (`B 1)) false
end

module Expression_extension = struct
  type t = {
    id : int;
    tags : string list;
  }
  [@@deriving eq]

  let run ~assert_bool_equal =
    (* The extension agrees with the derived function for a declared type... *)
    let left = { id = 1; tags = [ "a" ] } in
    let right = { id = 1; tags = [ "a" ] } in
    assert_bool_equal ([%eq: t] left right) (equal left right);
    assert_bool_equal ([%eq: t] left { right with id = 2 }) false;
    (* ...and works inline on types that were never declared. *)
    assert_bool_equal ([%eq: int list] [ 1; 2 ] [ 1; 2 ]) true;
    assert_bool_equal ([%eq: int list] [ 1; 2 ] [ 1; 3 ]) false;
    assert_bool_equal ([%eq: (int * string) option] (Some (1, "a")) (Some (1, "a"))) true;
    assert_bool_equal ([%eq: (int * string) option] (Some (1, "a")) None) false;
    (* Result types, the shape native tests explicitly. *)
    let equal_outcome = [%eq: (string, int) result] in
    assert_bool_equal (equal_outcome (Ok "a") (Ok "a")) true;
    assert_bool_equal (equal_outcome (Ok "a") (Ok "b")) false;
    assert_bool_equal (equal_outcome (Error 1) (Error 1)) true;
    assert_bool_equal (equal_outcome (Ok "a") (Error 1)) false;
    assert_bool_equal ([%derive.eq: int] 1 1) true
end

let all : Test_case.t list =
  [
    { name = "variant"; run = Variant.run };
    { name = "variant_payload"; run = Variant_payload.run };
    { name = "primitive_payloads"; run = Primitive_payloads.run };
    { name = "primitive_aliases"; run = Primitive_aliases.run };
    { name = "custom_payload"; run = Custom_payload.run };
    { name = "custom_attribute_payload"; run = Custom_attribute_payload.run };
    { name = "list_payload"; run = List_payload.run };
    { name = "option_payload"; run = Option_payload.run };
    { name = "array_payload"; run = Array_payload.run };
    { name = "result_payload"; run = Result_payload.run };
    { name = "tuple_payload"; run = Tuple_payload.run };
    { name = "polymorphic_variant"; run = Polymorphic_variant.run };
    { name = "type_alias"; run = Type_alias.run };
    { name = "type_t_alias"; run = Type_t_alias.run };
    { name = "type_t"; run = Type_t.run };
    { name = "module_signature"; run = Module_signature.run };
    { name = "record_type"; run = Record_type.run };
    { name = "record_payload_constructor"; run = Record_payload_constructor.run };
    { name = "record_field_custom_equal"; run = Record_field_custom_equal.run };
    { name = "tag_like_record"; run = Tag_like_record.run };
    { name = "parameterized_variant"; run = Parameterized_variant.run };
    { name = "phantom_parameter"; run = Phantom_parameter.run };
    { name = "generic_application"; run = Generic_application.run };
    { name = "mutually_recursive"; run = Mutually_recursive.run };
    { name = "alias_to_type_variable"; run = Alias_to_type_variable.run };
    { name = "recursive_group_alias"; run = Recursive_group_alias.run };
    { name = "generic_application_alias"; run = Generic_application_alias.run };
    { name = "fragile_match_regression"; run = Fragile_match_regression.run };
    { name = "expression_extension"; run = Expression_extension.run };
  ]
