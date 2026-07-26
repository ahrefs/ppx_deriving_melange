open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "ord"

let attr_compare =
  Attribute.declare "deriving.ord.compare" Attribute.Context.core_type Ast_pattern.(single_expr_payload __) Fun.id

let compare_name type_decl = mangle_type_decl ~prefix:"compare" type_decl
let type_parameter_compare_name typ = "poly_" ^ type_parameter_name ~deriver typ

let comparison_type typ =
  let loc = typ.ptyp_loc in
  [%type: [%t typ] -> [%t typ] -> int]

let type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let typ = core_type_of_type_decl type_decl in
  let base_type = [%type: [%t typ] -> [%t typ] -> int] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc -> Typ.arrow Nolabel (comparison_type type_param) acc)
    type_decl.ptype_params base_type

let primitive_compare typ = [%expr fun (a : [%t typ]) b -> Stdlib.compare a b]

let compare_expr_of_payload_lid loc typ = function
  | Lident ("string" | "int" | "bool" | "float" | "char" | "int32" | "int64" | "bytes" | "unit") ->
    primitive_compare typ
  | Ldot (Lident "Int32", "t") -> primitive_compare typ
  | Ldot (Lident "Int64", "t") -> primitive_compare typ
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"compare" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"compare" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in compare_expr_of_type_constructor.
       The functor-path error is covered by test/ord_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.ord doesn't support payload type %s" (string_of_core_type typ)

let compare_reduce acc expr =
  [%expr
    match [%e expr] with
    | 0 -> [%e acc]
    | result -> result]

let reduce_comparisons comparisons =
  match List.rev comparisons with
  | [] -> [%expr 0]
  | last :: rest -> List.fold_left compare_reduce last rest

let rec list_compare element_typ =
  let element_compare = compare_expr_of_core_type element_typ in
  [%expr
    let rec loop x y =
      match x, y with
      | [], [] -> 0
      | [], _head :: _tail -> -1
      | _head :: _tail, [] -> 1
      | a :: x, b :: y -> [%e compare_reduce [%expr loop x y] [%expr [%e element_compare] a b]]
    in
    fun x y -> loop x y]

and option_compare element_typ =
  let element_compare = compare_expr_of_core_type element_typ in
  [%expr
    fun x y ->
      match x, y with
      | None, None -> 0
      | Some a, Some b -> [%e element_compare] a b
      | None, Some _value -> -1
      | Some _value, None -> 1]

and array_compare element_typ =
  let element_compare = compare_expr_of_core_type element_typ in
  [%expr
    fun x y ->
      let rec loop i =
        if i = Array.length x then 0
        else [%e compare_reduce [%expr loop (i + 1)] [%expr [%e element_compare] x.(i) y.(i)]]
      in
      [%e compare_reduce [%expr loop 0] [%expr Stdlib.compare (Array.length x) (Array.length y)]]]

and result_compare ok_typ error_typ =
  let ok_compare = compare_expr_of_core_type ok_typ in
  let error_compare = compare_expr_of_core_type error_typ in
  [%expr
    fun x y ->
      match x, y with
      | Error a, Error b -> [%e error_compare] a b
      | Ok a, Ok b -> [%e ok_compare] a b
      | Ok _value, Error _error -> -1
      | Error _error, Ok _value -> 1]

and tuple_compare tuple_types =
  let left_pattern, left_exprs = tuple_bindings "a" tuple_types in
  let right_pattern, right_exprs = tuple_bindings "b" tuple_types in
  let comparisons =
    List.map2
      (fun typ (left_expr, right_expr) ->
        Exp.apply (compare_expr_of_core_type typ) [ Nolabel, left_expr; Nolabel, right_expr ])
      tuple_types (List.combine left_exprs right_exprs)
  in
  Exp.fun_ Nolabel None left_pattern (Exp.fun_ Nolabel None right_pattern (reduce_comparisons comparisons))

and compare_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.ord doesn't support payload type %s" (string_of_core_type typ)
  in
  match Attribute.get attr_compare typ with
  | Some compare_expr -> compare_expr
  | None ->
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
    compare_expr_of_type_constructor type_path_loc typ type_path type_args
  | Ptyp_any -> raise_unsupported typ
  | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported typ
  | Ptyp_tuple tuple_types -> tuple_compare tuple_types
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
  | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_compare variant_fields
  | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
  | Ptyp_package _package_type -> raise_unsupported typ
  | Ptyp_extension _extension -> raise_unsupported typ
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ

and compare_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.ord doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_compare element_typ
  | false, Lident "option", [ element_typ ] -> option_compare element_typ
  | false, Lident "array", [ element_typ ] -> array_compare element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_compare ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (compare_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, compare_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> compare_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (compare_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, compare_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> compare_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.ord cannot be derived for polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.ord cannot be derived for malformed constant polymorphic variant payloads"
  | false, [] -> Location.raise_errorf ~loc "deriving.ord cannot be derived for empty polymorphic variant payload cases"
  | false, [ _single_payload ] ->
    Location.raise_errorf ~loc "deriving.ord cannot be derived for this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.ord doesn't support inherited polymorphic variant rows"

and polyvariant_same_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.tuple [ Pat.variant label.txt None; Pat.variant label.txt None ]) [%expr 0]
  | Rtag (label, false, [ payload_type ]) ->
    let compare_fn = compare_expr_of_core_type payload_type in
    Exp.case
      (Pat.tuple [ Pat.variant label.txt (Some (pvar "a")); Pat.variant label.txt (Some (pvar "b")) ])
      (Exp.apply compare_fn [ Nolabel, Exp.ident (lid_of_string "a"); Nolabel, Exp.ident (lid_of_string "b") ])
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_index_case i field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.variant label.txt None) (eint ~loc i)
  | Rtag (label, false, [ _payload_type ]) -> Exp.case (Pat.variant label.txt (Some (Pat.any ()))) (eint ~loc i)
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_different_case field =
  match field.prf_desc with
  | Rtag (label, true, []) ->
    Exp.case (Pat.tuple [ Pat.variant label.txt None; Pat.any () ]) [%expr Stdlib.compare (to_int a) (to_int b)]
  | Rtag (label, false, [ _payload_type ]) ->
    Exp.case
      (Pat.tuple [ Pat.variant label.txt (Some (Pat.any ())); Pat.any () ])
      [%expr Stdlib.compare (to_int a) (to_int b)]
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_compare fields =
  let same_cases = List.map polyvariant_same_case fields in
  match fields with
  | [] | [ _ ] ->
    Exp.fun_ Nolabel None (pvar "a") (Exp.fun_ Nolabel None (pvar "b") (Exp.match_ [%expr a, b] same_cases))
  | _first :: _second :: _rest ->
    let index_cases = List.mapi polyvariant_index_case fields in
    let to_int_fn = Exp.fun_ Nolabel None (pvar "value") (Exp.match_ (Exp.ident (lid_of_string "value")) index_cases) in
    let different_cases = List.map polyvariant_different_case fields in
    Exp.fun_ Nolabel None (pvar "a")
      (Exp.fun_ Nolabel None (pvar "b")
         [%expr
           let to_int = [%e to_int_fn] in
           [%e Exp.match_ [%expr a, b] (same_cases @ different_cases)]])

let payload_comparison payload_types =
  let comparisons =
    List.mapi
      (fun i typ ->
        Exp.apply (compare_expr_of_core_type typ)
          [
            Nolabel, Exp.ident (lid_of_string ("a" ^ string_of_int i));
            Nolabel, Exp.ident (lid_of_string ("b" ^ string_of_int i));
          ])
      payload_types
  in
  reduce_comparisons comparisons

let record_payload_field_comparison field_decl =
  let field_name = field_decl.pld_name.txt in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  Exp.apply (compare_expr_of_core_type field_type)
    [ Nolabel, Exp.ident (lid_of_string ("a_" ^ field_name)); Nolabel, Exp.ident (lid_of_string ("b_" ^ field_name)) ]

let record_payload_comparison fields = reduce_comparisons (List.map record_payload_field_comparison fields)

let constructor_case_pattern name payload_types =
  ( constructor_pattern name (payload_pattern "a" payload_types),
    constructor_pattern name (payload_pattern "b" payload_types) )

let record_payload_case_pattern name fields =
  ( constructor_pattern name (Some (record_payload_pattern "a_" fields)),
    constructor_pattern name (Some (record_payload_pattern "b_" fields)) )

let same_constructor_case constructor =
  match constructor.pcd_args with
  | Pcstr_tuple payload_types ->
    let left, right = constructor_case_pattern constructor.pcd_name.txt payload_types in
    Exp.case (Pat.tuple [ left; right ]) (payload_comparison payload_types)
  | Pcstr_record record_payload_fields ->
    let left, right = record_payload_case_pattern constructor.pcd_name.txt record_payload_fields in
    Exp.case (Pat.tuple [ left; right ]) (record_payload_comparison record_payload_fields)

let constructor_index_case i constructor =
  let payload =
    match constructor.pcd_args with
    | Pcstr_tuple [] -> None
    | Pcstr_tuple _payload_types -> Some (Pat.any ())
    | Pcstr_record _record_payload_fields -> Some (Pat.any ())
  in
  Exp.case (constructor_pattern constructor.pcd_name.txt payload) (eint ~loc i)

let different_constructor_case constructor =
  let payload =
    match constructor.pcd_args with
    | Pcstr_tuple payload_types -> payload_pattern "_" payload_types
    | Pcstr_record _record_payload_fields -> Some (Pat.any ())
  in
  Exp.case
    (Pat.tuple [ constructor_pattern constructor.pcd_name.txt payload; Pat.any () ])
    [%expr Stdlib.compare (to_int a) (to_int b)]

let expr_of_variant constructors =
  let same_cases = List.map same_constructor_case constructors in
  match constructors with
  | [] | [ _ ] ->
    Exp.fun_ Nolabel None (pvar "a") (Exp.fun_ Nolabel None (pvar "b") (Exp.match_ [%expr a, b] same_cases))
  | _first :: _second :: _rest ->
    let index_cases = List.mapi constructor_index_case constructors in
    let to_int_fn = Exp.fun_ Nolabel None (pvar "value") (Exp.match_ (Exp.ident (lid_of_string "value")) index_cases) in
    let different_cases = List.map different_constructor_case constructors in
    Exp.fun_ Nolabel None (pvar "a")
      (Exp.fun_ Nolabel None (pvar "b")
         [%expr
           let to_int = [%e to_int_fn] in
           [%e Exp.match_ [%expr a, b] (same_cases @ different_cases)]])

let record_field_comparison field_decl =
  let field_name = field_decl.pld_name in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  let field_lid = mkloc (Lident field_name.txt) field_name.loc in
  Exp.apply (compare_expr_of_core_type field_type)
    [
      Nolabel, Exp.field (Exp.ident (lid_of_string "a")) field_lid;
      Nolabel, Exp.field (Exp.ident (lid_of_string "b")) field_lid;
    ]

let expr_of_record fields =
  let comparisons = List.map record_field_comparison fields in
  Exp.fun_ Nolabel None (pvar "a") (Exp.fun_ Nolabel None (pvar "b") (reduce_comparisons comparisons))

(* Aliases whose comparison is not already a lambda (type b = a, type t = float
   poly_abs) are eta-expanded so the binding stays a valid let-rec right-hand
   side. *)
let eta_expand_comparison compare_expr =
  if is_syntactic_function compare_expr then compare_expr else [%expr fun a b -> [%e compare_expr] a b]

let str_of_type ~deriver
  ({
     ptype_name = _type_name;
     ptype_params;
     ptype_cstrs = _type_constraints;
     ptype_kind;
     ptype_private = _type_private;
     ptype_manifest;
     ptype_attributes = _type_attributes;
     ptype_loc = loc;
   } as type_decl) =
  let compare_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> eta_expand_comparison (compare_expr_of_core_type manifest_type)
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let compare_exp =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_compare_name type_param)) acc)
      ptype_params compare_exp
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (compare_name type_decl)) (type_of_decl type_decl))
      compare_exp;
  ]

let sig_of_type type_decl = [ Sig.value (Val.mk (mknoloc (compare_name type_decl)) (type_of_decl type_decl)) ]

let str_type_decl ~deriver =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
