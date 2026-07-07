open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "map"
let map_name type_decl = mangle_type_decl ~prefix:"map" type_decl
let type_parameter_map_name typ = "poly_" ^ type_parameter_name ~deriver typ

let input_type_variable_names type_decl =
  List.map
    (fun (type_param, _variance_and_injectivity) -> type_parameter_name ~deriver type_param)
    type_decl.ptype_params

(* map is the only deriver whose signature needs distinct result type
   variables: ('a -> 'b) -> 'a t -> 'b t. Output names are the first free
   letters not used by the declared parameters ('a -> 'b; ('a, 'b) -> ('c, 'd);
   ('k, 'v) -> ('a, 'b)), with numbered suffixes past 'z'. *)
let output_type_variable_names type_decl =
  let input_names = input_type_variable_names type_decl in
  let candidate index =
    let letter = String.make 1 (Char.chr (Char.code 'a' + (index mod 26))) in
    match index / 26 with
    | 0 -> letter
    | round -> letter ^ string_of_int round
  in
  let rec take count index =
    match count with
    | 0 -> []
    | _remaining_count ->
      let name = candidate index in
      if List.mem name input_names then take count (index + 1) else name :: take (count - 1) (index + 1)
  in
  take (List.length input_names) 0

let type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let type_name = type_decl.ptype_name in
  let input_typ = core_type_of_type_decl type_decl in
  let output_names = output_type_variable_names type_decl in
  let output_typ = Typ.constr (mkloc (Lident type_name.txt) type_name.loc) (List.map Typ.var output_names) in
  let base_type = [%type: [%t input_typ] -> [%t output_typ]] in
  List.fold_right2
    (fun (type_param, _variance_and_injectivity) output_name acc ->
      Typ.arrow Nolabel [%type: [%t type_param] -> [%t Typ.var output_name]] acc)
    type_decl.ptype_params output_names base_type

(* The let-rec bindings are annotated with an explicitly polymorphic type
   ('a 'b. ...): plain named variables are scoped across the whole recursive
   binding group, so sibling declarations would silently unify each other's
   input and output variables (collapsing map to 'a -> 'a when parameter names
   differ) or fail the occur check when one declaration instantiates a sibling
   at a composite argument. The explicit quantifier scopes the variables per
   binding and permits polymorphic recursion across the group. *)
let annotation_of_decl type_decl =
  let typ = type_of_decl type_decl in
  match input_type_variable_names type_decl @ output_type_variable_names type_decl with
  | [] -> typ
  | _first_variable :: _remaining_variables as variable_names ->
    Typ.poly (List.map (fun name -> mkloc name type_decl.ptype_loc) variable_names) typ

let map_expr_of_payload_lid loc typ = function
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"map" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"map" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in map_expr_of_type_constructor.
       The functor-path error is covered by test/map_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.map doesn't support payload type %s" (string_of_core_type typ)

let rec map_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.map doesn't support payload type %s" (string_of_core_type typ)
  in
  match free_type_variables typ with
  | [] -> [%expr fun x -> x]
  | _first_free_variable :: _remaining_free_variables ->
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
    map_expr_of_type_constructor type_path_loc typ type_path type_args
  | Ptyp_any -> raise_unsupported typ
  | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported typ
  | Ptyp_tuple tuple_types -> tuple_map tuple_types
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
  | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_map variant_fields
  | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
  | Ptyp_package _package_type -> raise_unsupported typ
  | Ptyp_extension _extension -> raise_unsupported typ
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ

and map_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.map doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_map element_typ
  | false, Lident "option", [ element_typ ] -> option_map element_typ
  | false, Lident "array", [ element_typ ] -> array_map element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_map ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (map_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, map_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> map_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (map_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, map_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> map_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and list_map element_typ =
  let element_map = map_expr_of_core_type element_typ in
  [%expr List.map [%e element_map]]

and option_map element_typ =
  let element_map = map_expr_of_core_type element_typ in
  [%expr
    fun x ->
      match x with
      | None -> None
      | Some a -> Some ([%e element_map] a)]

and array_map element_typ =
  let element_map = map_expr_of_core_type element_typ in
  [%expr Array.map [%e element_map]]

and result_map ok_typ error_typ =
  let ok_map = map_expr_of_core_type ok_typ in
  let error_map = map_expr_of_core_type error_typ in
  [%expr
    fun x ->
      match x with
      | Ok a -> Ok ([%e ok_map] a)
      | Error b -> Error ([%e error_map] b)]

and tuple_map tuple_types =
  let pattern, expressions = tuple_bindings "a" tuple_types in
  let mapped_elements =
    List.map2
      (fun typ expression -> Exp.apply (map_expr_of_core_type typ) [ Nolabel, expression ])
      tuple_types expressions
  in
  Exp.fun_ Nolabel None pattern (Exp.tuple mapped_elements)

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.map cannot be derived for polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.map cannot be derived for malformed constant polymorphic variant payloads"
  | false, [] -> Location.raise_errorf ~loc "deriving.map cannot be derived for empty polymorphic variant payload cases"
  | false, [ _single_payload ] ->
    Location.raise_errorf ~loc "deriving.map cannot be derived for this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.map doesn't support inherited polymorphic variant rows"

and polyvariant_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.variant label.txt None) (Exp.variant label.txt None)
  | Rtag (label, false, [ payload_type ]) ->
    let payload_map = map_expr_of_core_type payload_type in
    Exp.case
      (Pat.variant label.txt (Some (pvar "a")))
      (Exp.variant label.txt (Some (Exp.apply payload_map [ Nolabel, Exp.ident (lid_of_string "a") ])))
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_map fields =
  let cases = List.map polyvariant_case fields in
  Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases)

let record_field_mapping field_decl =
  let field_name = field_decl.pld_name in
  let field_lid = mkloc (Lident field_name.txt) field_name.loc in
  ( field_lid,
    Exp.apply
      (map_expr_of_core_type field_decl.pld_type)
      [ Nolabel, Exp.field (Exp.ident (lid_of_string "x")) field_lid ] )

let expr_of_record fields =
  let mapped_fields = List.map record_field_mapping fields in
  Exp.fun_ Nolabel None (pvar "x") (Exp.record mapped_fields None)

let constructor_payload_expr mapped_arguments =
  match mapped_arguments with
  | [] -> None
  | [ single_argument ] -> Some single_argument
  | _first_argument :: _second_argument :: _remaining_arguments -> Some (Exp.tuple mapped_arguments)

let constructor_case constructor =
  let constructor_lid = lid_of_string constructor.pcd_name.txt in
  match constructor.pcd_args with
  | Pcstr_tuple payload_types ->
    let pattern = constructor_pattern constructor.pcd_name.txt (payload_pattern "a" payload_types) in
    let mapped_arguments =
      List.mapi
        (fun i typ ->
          Exp.apply (map_expr_of_core_type typ) [ Nolabel, Exp.ident (lid_of_string ("a" ^ string_of_int i)) ])
        payload_types
    in
    Exp.case pattern (Exp.construct constructor_lid (constructor_payload_expr mapped_arguments))
  | Pcstr_record record_payload_fields ->
    let pattern =
      constructor_pattern constructor.pcd_name.txt (Some (record_payload_pattern "a_" record_payload_fields))
    in
    let mapped_fields =
      List.map
        (fun field_decl ->
          let field_name = field_decl.pld_name in
          let field_lid = mkloc (Lident field_name.txt) field_name.loc in
          ( field_lid,
            Exp.apply
              (map_expr_of_core_type field_decl.pld_type)
              [ Nolabel, Exp.ident (lid_of_string ("a_" ^ field_name.txt)) ] ))
        record_payload_fields
    in
    Exp.case pattern (Exp.construct constructor_lid (Some (Exp.record mapped_fields None)))

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
  let map_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> map_expr_of_core_type manifest_type
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let map_exp =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_map_name type_param)) acc)
      ptype_params map_exp
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (map_name type_decl)) (annotation_of_decl type_decl))
      map_exp;
  ]

let sig_of_type type_decl = [ Sig.value (Val.mk (mknoloc (map_name type_decl)) (type_of_decl type_decl)) ]

let str_type_decl ~deriver =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
