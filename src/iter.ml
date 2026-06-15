open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "iter"
let iter_name type_decl = mangle_type_decl ~prefix:"iter" type_decl
let type_parameter_iter_name typ = "poly_" ^ type_parameter_name ~deriver typ

let iteration_type typ =
  let loc = typ.ptyp_loc in
  [%type: [%t typ] -> unit]

let type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let typ = core_type_of_type_decl type_decl in
  let base_type = [%type: [%t typ] -> unit] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc -> Typ.arrow Nolabel (iteration_type type_param) acc)
    type_decl.ptype_params base_type

let iter_expr_of_payload_lid loc typ = function
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"iter" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"iter" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in iter_expr_of_type_constructor.
       The functor-path error is covered by test/iter_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.iter doesn't support payload type %s" (string_of_core_type typ)

let sequence_iterations iterations =
  match iterations with
  | [] -> [%expr ()]
  | first :: rest -> List.fold_left (fun acc expr -> Exp.sequence acc expr) first rest

let rec iter_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.iter doesn't support payload type %s" (string_of_core_type typ)
  in
  match free_type_variables typ with
  | [] -> [%expr fun _ -> ()]
  | _first_free_variable :: _remaining_free_variables ->
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
    iter_expr_of_type_constructor type_path_loc typ type_path type_args
  | Ptyp_any -> raise_unsupported typ
  | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported typ
  | Ptyp_tuple tuple_types -> tuple_iter tuple_types
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
  | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_iter variant_fields
  | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
  | Ptyp_package _package_type -> raise_unsupported typ
  | Ptyp_extension _extension -> raise_unsupported typ
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ

and iter_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.iter doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_iter element_typ
  | false, Lident "option", [ element_typ ] -> option_iter element_typ
  | false, Lident "array", [ element_typ ] -> array_iter element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_iter ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (iter_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, iter_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> iter_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (iter_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, iter_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> iter_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and list_iter element_typ =
  let element_iter = iter_expr_of_core_type element_typ in
  [%expr List.iter [%e element_iter]]

and option_iter element_typ =
  let element_iter = iter_expr_of_core_type element_typ in
  [%expr
    fun x ->
      match x with
      | None -> ()
      | Some a -> [%e element_iter] a]

and array_iter element_typ =
  let element_iter = iter_expr_of_core_type element_typ in
  [%expr Array.iter [%e element_iter]]

and result_iter ok_typ error_typ =
  let ok_iter = iter_expr_of_core_type ok_typ in
  let error_iter = iter_expr_of_core_type error_typ in
  [%expr
    fun x ->
      match x with
      | Ok a -> [%e ok_iter] a
      | Error b -> [%e error_iter] b]

and tuple_iter tuple_types =
  let pattern, expressions = tuple_bindings "a" tuple_types in
  let iterations =
    List.map2
      (fun typ expression -> Exp.apply (iter_expr_of_core_type typ) [ Nolabel, expression ])
      tuple_types expressions
  in
  Exp.fun_ Nolabel None pattern (sequence_iterations iterations)

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.iter cannot be derived for polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.iter cannot be derived for malformed constant polymorphic variant payloads"
  | false, [] ->
    Location.raise_errorf ~loc "deriving.iter cannot be derived for empty polymorphic variant payload cases"
  | false, [ _single_payload ] ->
    Location.raise_errorf ~loc "deriving.iter cannot be derived for this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.iter doesn't support inherited polymorphic variant rows"

and polyvariant_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.variant label.txt None) [%expr ()]
  | Rtag (label, false, [ payload_type ]) ->
    let payload_iter = iter_expr_of_core_type payload_type in
    Exp.case
      (Pat.variant label.txt (Some (pvar "a")))
      (Exp.apply payload_iter [ Nolabel, Exp.ident (lid_of_string "a") ])
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_iter fields =
  let cases = List.map polyvariant_case fields in
  Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases)

let record_field_iteration field_decl =
  let field_name = field_decl.pld_name in
  let field_lid = mkloc (Lident field_name.txt) field_name.loc in
  Exp.apply
    (iter_expr_of_core_type field_decl.pld_type)
    [ Nolabel, Exp.field (Exp.ident (lid_of_string "x")) field_lid ]

let expr_of_record fields =
  let iterations = List.map record_field_iteration fields in
  Exp.fun_ Nolabel None (pvar "x") (sequence_iterations iterations)

let constructor_case constructor =
  match constructor.pcd_args with
  | Pcstr_tuple payload_types ->
    let pattern = constructor_pattern constructor.pcd_name.txt (payload_pattern "a" payload_types) in
    let iterations =
      List.mapi
        (fun i typ ->
          Exp.apply (iter_expr_of_core_type typ) [ Nolabel, Exp.ident (lid_of_string ("a" ^ string_of_int i)) ])
        payload_types
    in
    Exp.case pattern (sequence_iterations iterations)
  | Pcstr_record record_payload_fields ->
    let pattern =
      constructor_pattern constructor.pcd_name.txt (Some (record_payload_pattern "a_" record_payload_fields))
    in
    let iterations =
      List.map
        (fun field_decl ->
          Exp.apply
            (iter_expr_of_core_type field_decl.pld_type)
            [ Nolabel, Exp.ident (lid_of_string ("a_" ^ field_decl.pld_name.txt)) ])
        record_payload_fields
    in
    Exp.case pattern (sequence_iterations iterations)

let expr_of_variant constructors =
  let cases = List.map constructor_case constructors in
  Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases)

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
  let iter_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> iter_expr_of_core_type manifest_type
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let iter_exp =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_iter_name type_param)) acc)
      ptype_params iter_exp
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (iter_name type_decl)) (type_of_decl type_decl))
      iter_exp;
  ]

let sig_of_type type_decl = [ Sig.value (Val.mk (mknoloc (iter_name type_decl)) (type_of_decl type_decl)) ]

let str_type_decl ~deriver =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
