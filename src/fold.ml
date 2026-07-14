open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "fold"
let fold_name type_decl = mangle_type_decl ~prefix:"fold" type_decl
let type_parameter_fold_name typ = "poly_" ^ type_parameter_name ~deriver typ

let input_type_variable_names type_decl =
  List.map
    (fun (type_param, _variance_and_injectivity) -> type_parameter_name ~deriver type_param)
    type_decl.ptype_params

(* The accumulator gets its own type variable: ('acc -> 'a -> 'acc) -> 'acc ->
   'a t -> 'acc, one accumulator shared by every callback. Its name is the
   first free letter not used by the declared parameters ('a t -> 'b;
   ('a, 'b) t -> 'c; ('b, 'c) t -> 'a), with numbered suffixes past 'z'. *)
let accumulator_type_variable_name type_decl =
  let input_names = input_type_variable_names type_decl in
  let candidate index =
    let letter = String.make 1 (Char.chr (Char.code 'a' + (index mod 26))) in
    match index / 26 with
    | 0 -> letter
    | round -> letter ^ string_of_int round
  in
  let rec pick index =
    let name = candidate index in
    if List.mem name input_names then pick (index + 1) else name
  in
  pick 0

let type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let input_typ = core_type_of_type_decl type_decl in
  let accumulator_typ = Typ.var (accumulator_type_variable_name type_decl) in
  let base_type = [%type: [%t accumulator_typ] -> [%t input_typ] -> [%t accumulator_typ]] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc ->
      Typ.arrow Nolabel [%type: [%t accumulator_typ] -> [%t type_param] -> [%t accumulator_typ]] acc)
    type_decl.ptype_params base_type

(* The let-rec bindings are annotated with an explicitly polymorphic type
   ('a 'b. ...), like map: plain named variables are scoped across the whole
   recursive binding group, so sibling declarations would silently unify each
   other's variables or fail the occur check when one declaration instantiates
   a sibling at a composite argument. Unlike map, every fold binding has at
   least one variable to quantify — the accumulator — so zero-parameter
   declarations are quantified too. *)
let annotation_of_decl type_decl =
  let typ = type_of_decl type_decl in
  let variable_names = input_type_variable_names type_decl @ [ accumulator_type_variable_name type_decl ] in
  Typ.poly (List.map (fun name -> mkloc name type_decl.ptype_loc) variable_names) typ

let fold_expr_of_payload_lid loc typ = function
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"fold" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"fold" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in fold_expr_of_type_constructor.
       The functor-path error is covered by test/fold_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.fold doesn't support payload type %s" (string_of_core_type typ)

(* Each expression evaluates to the accumulator after folding one value;
   chaining threads the result into the next fold in lexical order. *)
let rec chain_folds folds =
  match folds with
  | [] -> [%expr acc]
  | [ single_fold ] -> single_fold
  | first_fold :: remaining_folds ->
    [%expr
      let acc = [%e first_fold] in
      [%e chain_folds remaining_folds]]

let rec fold_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.fold doesn't support payload type %s" (string_of_core_type typ)
  in
  match free_type_variables typ with
  | [] -> [%expr fun acc _ -> acc]
  | _first_free_variable :: _remaining_free_variables ->
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
    fold_expr_of_type_constructor type_path_loc typ type_path type_args
  | Ptyp_any -> raise_unsupported typ
  | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported typ
  | Ptyp_tuple tuple_types -> tuple_fold tuple_types
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
  | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_fold variant_fields
  | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
  | Ptyp_package _package_type -> raise_unsupported typ
  | Ptyp_extension _extension -> raise_unsupported typ
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ

and fold_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.fold doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_fold element_typ
  | false, Lident "option", [ element_typ ] -> option_fold element_typ
  | false, Lident "array", [ element_typ ] -> array_fold element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_fold ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (fold_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, fold_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> fold_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (fold_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, fold_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> fold_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and list_fold element_typ =
  let element_fold = fold_expr_of_core_type element_typ in
  [%expr List.fold_left [%e element_fold]]

and option_fold element_typ =
  let element_fold = fold_expr_of_core_type element_typ in
  [%expr
    fun acc x ->
      match x with
      | None -> acc
      | Some a -> [%e element_fold] acc a]

and array_fold element_typ =
  let element_fold = fold_expr_of_core_type element_typ in
  [%expr Array.fold_left [%e element_fold]]

and result_fold ok_typ error_typ =
  let ok_fold = fold_expr_of_core_type ok_typ in
  let error_fold = fold_expr_of_core_type error_typ in
  [%expr
    fun acc x ->
      match x with
      | Ok a -> [%e ok_fold] acc a
      | Error b -> [%e error_fold] acc b]

and tuple_fold tuple_types =
  let pattern, expressions = tuple_bindings "a" tuple_types in
  let folds =
    List.map2
      (fun typ expression -> Exp.apply (fold_expr_of_core_type typ) [ Nolabel, [%expr acc]; Nolabel, expression ])
      tuple_types expressions
  in
  Exp.fun_ Nolabel None (pvar "acc") (Exp.fun_ Nolabel None pattern (chain_folds folds))

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.fold cannot be derived for polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.fold cannot be derived for malformed constant polymorphic variant payloads"
  | false, [] ->
    Location.raise_errorf ~loc "deriving.fold cannot be derived for empty polymorphic variant payload cases"
  | false, [ _single_payload ] ->
    Location.raise_errorf ~loc "deriving.fold cannot be derived for this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.fold doesn't support inherited polymorphic variant rows"

and polyvariant_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.variant label.txt None) [%expr acc]
  | Rtag (label, false, [ payload_type ]) ->
    let payload_fold = fold_expr_of_core_type payload_type in
    Exp.case
      (Pat.variant label.txt (Some (pvar "a")))
      (Exp.apply payload_fold [ Nolabel, [%expr acc]; Nolabel, Exp.ident (lid_of_string "a") ])
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_fold fields =
  let cases = List.map polyvariant_case fields in
  Exp.fun_ Nolabel None (pvar "acc") (Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases))

let record_field_fold field_decl =
  let field_name = field_decl.pld_name in
  let field_lid = mkloc (Lident field_name.txt) field_name.loc in
  Exp.apply
    (fold_expr_of_core_type field_decl.pld_type)
    [ Nolabel, [%expr acc]; Nolabel, Exp.field (Exp.ident (lid_of_string "x")) field_lid ]

let expr_of_record fields =
  let folds = List.map record_field_fold fields in
  Exp.fun_ Nolabel None (pvar "acc") (Exp.fun_ Nolabel None (pvar "x") (chain_folds folds))

let constructor_case constructor =
  match constructor.pcd_args with
  | Pcstr_tuple payload_types ->
    let pattern = constructor_pattern constructor.pcd_name.txt (payload_pattern "a" payload_types) in
    let folds =
      List.mapi
        (fun i typ ->
          Exp.apply (fold_expr_of_core_type typ)
            [ Nolabel, [%expr acc]; Nolabel, Exp.ident (lid_of_string ("a" ^ string_of_int i)) ])
        payload_types
    in
    Exp.case pattern (chain_folds folds)
  | Pcstr_record record_payload_fields ->
    let pattern =
      constructor_pattern constructor.pcd_name.txt (Some (record_payload_pattern "a_" record_payload_fields))
    in
    let folds =
      List.map
        (fun field_decl ->
          Exp.apply
            (fold_expr_of_core_type field_decl.pld_type)
            [ Nolabel, [%expr acc]; Nolabel, Exp.ident (lid_of_string ("a_" ^ field_decl.pld_name.txt)) ])
        record_payload_fields
    in
    Exp.case pattern (chain_folds folds)

let expr_of_variant constructors =
  let cases = List.map constructor_case constructors in
  Exp.fun_ Nolabel None (pvar "acc") (Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases))

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
  let fold_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> fold_expr_of_core_type manifest_type
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let fold_exp =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_fold_name type_param)) acc)
      ptype_params fold_exp
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (fold_name type_decl)) (annotation_of_decl type_decl))
      fold_exp;
  ]

let sig_of_type type_decl = [ Sig.value (Val.mk (mknoloc (fold_name type_decl)) (type_of_decl type_decl)) ]

let str_type_decl ~deriver =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
