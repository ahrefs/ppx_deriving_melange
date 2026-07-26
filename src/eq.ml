open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "eq"

let attr_equal =
  Attribute.declare "deriving.eq.equal" Attribute.Context.core_type Ast_pattern.(single_expr_payload __) Fun.id

let equal_name type_decl = mangle_type_decl ~prefix:"equal" type_decl
let type_parameter_equal_name typ = "poly_" ^ type_parameter_name ~deriver typ

let equality_type typ =
  let loc = typ.ptyp_loc in
  [%type: [%t typ] -> [%t typ] -> bool]

let type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let typ = core_type_of_type_decl type_decl in
  let base_type = [%type: [%t typ] -> [%t typ] -> bool] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc -> Typ.arrow Nolabel (equality_type type_param) acc)
    type_decl.ptype_params base_type

let primitive_equal typ = [%expr fun (a : [%t typ]) b -> a = b]

let equal_expr_of_payload_lid loc typ = function
  | Lident ("string" | "int" | "bool" | "float" | "char" | "int32" | "int64" | "bytes" | "unit") -> primitive_equal typ
  | Ldot (Lident "Int32", "t") -> primitive_equal typ
  | Ldot (Lident "Int64", "t") -> primitive_equal typ
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"equal" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"equal" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in equal_expr_of_type_constructor.
       The functor-path error is covered by test/eq_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.eq doesn't support payload type %s" (string_of_core_type typ)

let fold_comparisons comparisons =
  match comparisons with
  | [] -> [%expr true]
  | first :: rest -> List.fold_left (fun acc expr -> [%expr [%e acc] && [%e expr]]) first rest

let rec list_equal element_typ =
  let element_equal = equal_expr_of_core_type element_typ in
  [%expr
    let rec loop x y =
      match x, y with
      | [], [] -> true
      | a :: x, b :: y -> [%e element_equal] a b && loop x y
      | [], _head :: _tail -> false
      | _head :: _tail, [] -> false
    in
    fun x y -> loop x y]

and option_equal element_typ =
  let element_equal = equal_expr_of_core_type element_typ in
  [%expr
    fun x y ->
      match x, y with
      | None, None -> true
      | Some a, Some b -> [%e element_equal] a b
      | None, Some _value -> false
      | Some _value, None -> false]

and array_equal element_typ =
  let element_equal = equal_expr_of_core_type element_typ in
  [%expr
    fun x y ->
      let rec loop i = i = Array.length x || ([%e element_equal] x.(i) y.(i) && loop (i + 1)) in
      Array.length x = Array.length y && loop 0]

and result_equal ok_typ error_typ =
  let ok_equal = equal_expr_of_core_type ok_typ in
  let error_equal = equal_expr_of_core_type error_typ in
  [%expr
    fun x y ->
      match x, y with
      | Ok a, Ok b -> [%e ok_equal] a b
      | Error a, Error b -> [%e error_equal] a b
      | Ok _value, Error _error -> false
      | Error _error, Ok _value -> false]

and tuple_equal tuple_types =
  let left_pattern, left_exprs = tuple_bindings "left" tuple_types in
  let right_pattern, right_exprs = tuple_bindings "right" tuple_types in
  let tuple_pair_pattern = Pat.tuple [ left_pattern; right_pattern ] in
  let comparisons =
    List.map2
      (fun typ (left_expr, right_expr) ->
        let equal_fn = equal_expr_of_core_type typ in
        Exp.apply equal_fn [ Nolabel, left_expr; Nolabel, right_expr ])
      tuple_types (List.combine left_exprs right_exprs)
  in
  Exp.fun_ Nolabel None (pvar "left")
    (Exp.fun_ Nolabel None (pvar "right")
       (Exp.match_ [%expr left, right] [ Exp.case tuple_pair_pattern (fold_comparisons comparisons) ]))

and equal_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.eq doesn't support payload type %s" (string_of_core_type typ)
  in
  match Attribute.get attr_equal typ with
  | Some equal_expr -> equal_expr
  | None ->
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
    equal_expr_of_type_constructor type_path_loc typ type_path type_args
  | Ptyp_any -> raise_unsupported typ
  | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported typ
  | Ptyp_tuple tuple_types -> tuple_equal tuple_types
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
  | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_equal variant_fields
  | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
  | Ptyp_package _package_type -> raise_unsupported typ
  | Ptyp_extension _extension -> raise_unsupported typ
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ

and equal_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.eq doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_equal element_typ
  | false, Lident "option", [ element_typ ] -> option_equal element_typ
  | false, Lident "array", [ element_typ ] -> array_equal element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_equal ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (equal_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, equal_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> equal_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (equal_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, equal_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> equal_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.eq doesn't support polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.eq doesn't support malformed constant polymorphic variant payloads"
  | false, [] -> Location.raise_errorf ~loc "deriving.eq doesn't support empty polymorphic variant payload cases"
  | false, [ _single_payload ] -> Location.raise_errorf ~loc "deriving.eq doesn't support this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.eq doesn't support inherited polymorphic variant rows"

and polyvariant_same_case field =
  match field.prf_desc with
  | Rtag (label, true, []) ->
    Exp.case (Pat.tuple [ Pat.variant label.txt None; Pat.variant label.txt None ]) [%expr true]
  | Rtag (label, false, [ payload_type ]) ->
    let equal_fn = equal_expr_of_core_type payload_type in
    Exp.case
      (Pat.tuple [ Pat.variant label.txt (Some (pvar "a")); Pat.variant label.txt (Some (pvar "b")) ])
      (Exp.apply equal_fn [ Nolabel, Exp.ident (lid_of_string "a"); Nolabel, Exp.ident (lid_of_string "b") ])
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_different_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.tuple [ Pat.variant label.txt None; Pat.any () ]) [%expr false]
  | Rtag (label, false, [ _payload_type ]) ->
    Exp.case (Pat.tuple [ Pat.variant label.txt (Some (Pat.any ())); Pat.any () ]) [%expr false]
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_equal fields =
  let true_cases = List.map polyvariant_same_case fields in
  let false_cases =
    match fields with
    | [] -> []
    | [ _single_field ] -> []
    | _first_field :: _second_field :: _remaining_fields -> List.map polyvariant_different_case fields
  in
  [%expr fun lhs rhs -> [%e Exp.match_ [%expr lhs, rhs] (true_cases @ false_cases)]]

let constructor_case_pattern name payload_types =
  ( constructor_pattern name (payload_pattern "a" payload_types),
    constructor_pattern name (payload_pattern "b" payload_types) )

let record_payload_case_pattern name fields =
  ( constructor_pattern name (Some (record_payload_pattern "a_" fields)),
    constructor_pattern name (Some (record_payload_pattern "b_" fields)) )

let payload_comparison payload_types =
  let comparisons =
    List.mapi
      (fun i typ ->
        let equal_fn = equal_expr_of_core_type typ in
        Exp.apply equal_fn
          [
            Nolabel, Exp.ident (lid_of_string ("a" ^ string_of_int i));
            Nolabel, Exp.ident (lid_of_string ("b" ^ string_of_int i));
          ])
      payload_types
  in
  match comparisons with
  | [] -> [%expr true]
  | first :: rest -> List.fold_left (fun acc expr -> [%expr [%e acc] && [%e expr]]) first rest

let record_payload_field_comparison field_decl =
  let field_name = field_decl.pld_name.txt in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  let equal_fn = equal_expr_of_core_type field_type in
  Exp.apply equal_fn
    [ Nolabel, Exp.ident (lid_of_string ("a_" ^ field_name)); Nolabel, Exp.ident (lid_of_string ("b_" ^ field_name)) ]

let record_payload_comparison fields =
  let comparisons = List.map record_payload_field_comparison fields in
  fold_comparisons comparisons

let record_field_comparison field_decl =
  let field_name = field_decl.pld_name in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  let field_lid = mkloc (Lident field_name.txt) field_name.loc in
  let equal_fn = equal_expr_of_core_type field_type in
  Exp.apply equal_fn
    [
      Nolabel, Exp.field (Exp.ident (lid_of_string "lhs")) field_lid;
      Nolabel, Exp.field (Exp.ident (lid_of_string "rhs")) field_lid;
    ]

let expr_of_record fields =
  let comparisons = List.map record_field_comparison fields in
  Exp.fun_ Nolabel None (pvar "lhs") (Exp.fun_ Nolabel None (pvar "rhs") (fold_comparisons comparisons))

let same_constructor_case constructor =
  match constructor.pcd_args with
  | Pcstr_tuple payload_types ->
    let left, right = constructor_case_pattern constructor.pcd_name.txt payload_types in
    Exp.case (Pat.tuple [ left; right ]) (payload_comparison payload_types)
  | Pcstr_record record_payload_fields ->
    let left, right = record_payload_case_pattern constructor.pcd_name.txt record_payload_fields in
    Exp.case (Pat.tuple [ left; right ]) (record_payload_comparison record_payload_fields)

let different_constructor_case constructor =
  let payload =
    match constructor.pcd_args with
    | Pcstr_tuple payload_types -> payload_pattern "_" payload_types
    | Pcstr_record _record_payload_fields -> Some (Pat.any ())
  in
  Exp.case (Pat.tuple [ constructor_pattern constructor.pcd_name.txt payload; Pat.any () ]) [%expr false]

let expr_of_variant constructors =
  let true_cases = List.map same_constructor_case constructors in
  let false_cases =
    match constructors with
    | [] -> []
    | [ _single_constructor ] -> []
    | _first_constructor :: _second_constructor :: _remaining_constructors ->
      List.map different_constructor_case constructors
  in
  Exp.fun_ Nolabel None (pvar "a")
    (Exp.fun_ Nolabel None (pvar "b") (Exp.match_ [%expr a, b] (true_cases @ false_cases)))

(* Aliases whose equality is not already a lambda (type b = a, type t = float
   poly_abs) are eta-expanded so the binding stays a valid let-rec right-hand
   side. *)
let eta_expand_equality equal_expr =
  if is_syntactic_function equal_expr then equal_expr else [%expr fun a b -> [%e equal_expr] a b]

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
  let equal_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> eta_expand_equality (equal_expr_of_core_type manifest_type)
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let equal_exp =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_equal_name type_param)) acc)
      ptype_params equal_exp
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (equal_name type_decl)) (type_of_decl type_decl))
      equal_exp;
  ]

let sig_of_type type_decl = [ Sig.value (Val.mk (mknoloc (equal_name type_decl)) (type_of_decl type_decl)) ]

let str_type_decl ~deriver =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
