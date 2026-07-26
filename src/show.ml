open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "show"

let attr_printer =
  Attribute.declare "deriving.show.printer" Attribute.Context.core_type Ast_pattern.(single_expr_payload __) Fun.id

let attr_constructor_printer =
  Attribute.declare "deriving.show.printer" Attribute.Context.constructor_declaration
    Ast_pattern.(single_expr_payload __)
    Fun.id

let attr_opaque = Attribute.declare_flag "deriving.show.opaque" Attribute.Context.core_type

let pp_name type_decl = mangle_type_decl ~prefix:"pp" type_decl
let show_name type_decl = mangle_type_decl ~prefix:"show" type_decl
let type_parameter_printer_name typ = "poly_" ^ type_parameter_name ~deriver typ

let printer_type typ =
  let loc = typ.ptyp_loc in
  [%type: Stdlib.Format.formatter -> [%t typ] -> unit]

let pp_type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let typ = core_type_of_type_decl type_decl in
  let base_type = [%type: Stdlib.Format.formatter -> [%t typ] -> unit] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc -> Typ.arrow Nolabel (printer_type type_param) acc)
    type_decl.ptype_params base_type

let show_type_of_decl type_decl =
  let loc = type_decl.ptype_loc in
  let typ = core_type_of_type_decl type_decl in
  let base_type = [%type: [%t typ] -> string] in
  List.fold_right
    (fun (type_param, _variance_and_injectivity) acc -> Typ.arrow Nolabel (printer_type type_param) acc)
    type_decl.ptype_params base_type

let expand_path ~with_path ~path name = if with_path then String.concat "." (path @ [ name ]) else name

(* Native parity: a re-exported definition (type u = M.s = A | B) prints its
   constructors with the manifest's module path, and a manifest referring to a
   local name drops the path entirely. *)
let path_of_type_decl ~path type_decl =
  match type_decl.ptype_manifest with
  | None -> path
  | Some { ptyp_desc = Ptyp_constr ({ txt = Lident _local_name; _ }, _type_args); _ } -> []
  | Some { ptyp_desc = Ptyp_constr ({ txt = Ldot (parent_path, _type_name); _ }, _type_args); _ } ->
    if has_functor_application parent_path then [] else Longident.flatten_exn parent_path
  | Some { ptyp_desc = Ptyp_constr ({ txt = Lapply (_left_path, _right_path); _ }, _type_args); _ } -> []
  | Some _non_constructor_manifest -> path

(* Native parity: the default path is the capitalized input file basename plus
   the submodule path, so with_path = true output matches native
   ppx_deriving.show. *)
let module_path_of_context ctxt =
  let code_path = Expansion_context.Deriver.code_path ctxt in
  let main_module_path =
    match Expansion_context.Deriver.input_name ctxt with
    | "" | "_none_" -> []
    | input_name ->
    match Filename.chop_suffix input_name ".ml" with
    | exception _not_an_ml_file -> []
    | base_path -> [ String.capitalize_ascii (Filename.basename base_path) ]
  in
  main_module_path @ Code_path.submodule_path code_path

(* Native ppx_deriving.show exposes a local [fprintf] to custom printers so the
   [@printer fun fmt -> fprintf fmt "..."] idiom works; -26 silences the unused
   binding when the printer doesn't use it. *)
let wrap_printer printer_expr =
  let loc = printer_expr.pexp_loc in
  [%expr
    (let fprintf = Stdlib.Format.fprintf in
     [%e printer_expr])
    [@ocaml.warning "-26"]]

let sequence expressions =
  match expressions with
  | [] -> [%expr ()]
  | first :: rest -> List.fold_left (fun acc expression -> Exp.sequence acc expression) first rest

let separated ~separator expressions =
  let rec interleave = function
    | ([] | [ _ ]) as tail -> tail
    | first :: rest -> first :: separator :: interleave rest
  in
  interleave expressions

let print format_string = [%expr Stdlib.Format.fprintf fmt [%e estring ~loc format_string]]

(* The common output plan of every composite shape, as one generated statement:
   print [before]; the given statements with [sep] printed between them; print
   [after]. *)
let print_between ~before ~sep ~after statements =
  sequence ((print before :: separated ~separator:(print sep) statements) @ [ print after ])

let primitive_printer typ name =
  let loc = typ.ptyp_loc in
  let format_printer format_string = [%expr fun fmt x -> Stdlib.Format.fprintf fmt [%e estring ~loc format_string] x] in
  match name with
  | "unit" -> [%expr fun fmt () -> Stdlib.Format.pp_print_string fmt "()"]
  | "bytes" -> [%expr fun fmt x -> Stdlib.Format.fprintf fmt "%S" (Bytes.to_string x)]
  | "int" -> format_printer "%d"
  | "int32" -> format_printer "%ldl"
  | "int64" -> format_printer "%LdL"
  | "float" -> format_printer "%F"
  | "bool" -> format_printer "%B"
  | "char" -> format_printer "%C"
  | "string" -> format_printer "%S"
  | _other_name ->
    (* Unreachable: pp_expr_of_payload_lid only dispatches the names above. *)
    Location.raise_errorf ~loc "deriving.show doesn't support payload type %s" (string_of_core_type typ)

let rec list_printer element_typ =
  let element_printer = pp_expr_of_core_type element_typ in
  [%expr
    fun fmt x ->
      Stdlib.Format.fprintf fmt "@[<2>[";
      ignore
        (List.fold_left
           (fun sep x ->
             if sep then Stdlib.Format.fprintf fmt ";@ ";
             [%e element_printer] fmt x;
             true)
           false x);
      Stdlib.Format.fprintf fmt "@,]@]"]

and array_printer element_typ =
  let element_printer = pp_expr_of_core_type element_typ in
  [%expr
    fun fmt x ->
      Stdlib.Format.fprintf fmt "@[<2>[|";
      ignore
        (Array.fold_left
           (fun sep x ->
             if sep then Stdlib.Format.fprintf fmt ";@ ";
             [%e element_printer] fmt x;
             true)
           false x);
      Stdlib.Format.fprintf fmt "@,|]@]"]

and option_printer element_typ =
  let element_printer = pp_expr_of_core_type element_typ in
  [%expr
    fun fmt x ->
      match x with
      | None -> Stdlib.Format.pp_print_string fmt "None"
      | Some value ->
        Stdlib.Format.pp_print_string fmt "(Some ";
        [%e element_printer] fmt value;
        Stdlib.Format.pp_print_string fmt ")"]

and result_printer ok_typ error_typ =
  let ok_printer = pp_expr_of_core_type ok_typ in
  let error_printer = pp_expr_of_core_type error_typ in
  [%expr
    fun fmt x ->
      match x with
      | Ok value ->
        Stdlib.Format.pp_print_string fmt "(Ok ";
        [%e ok_printer] fmt value;
        Stdlib.Format.pp_print_string fmt ")"
      | Error error ->
        Stdlib.Format.pp_print_string fmt "(Error ";
        [%e error_printer] fmt error;
        Stdlib.Format.pp_print_string fmt ")"]

and tuple_printer tuple_types =
  let pattern, expressions = tuple_bindings "a" tuple_types in
  let element_printers =
    List.map2 (fun typ expression -> [%expr [%e pp_expr_of_core_type typ] fmt [%e expression]]) tuple_types expressions
  in
  Exp.fun_ Nolabel None (pvar "fmt")
    (Exp.fun_ Nolabel None pattern (print_between ~before:"(@[" ~sep:",@ " ~after:"@])" element_printers))

and raise_unsupported_polyvariant_rtag ~loc ~is_constant ~payload_types =
  match is_constant, payload_types with
  | false, _first_payload :: _second_payload :: _remaining_payloads ->
    Location.raise_errorf ~loc "deriving.show cannot be derived for polymorphic variant cases with multiple payloads"
  | true, _unexpected_payloads ->
    Location.raise_errorf ~loc "deriving.show cannot be derived for malformed constant polymorphic variant payloads"
  | false, [] ->
    Location.raise_errorf ~loc "deriving.show cannot be derived for empty polymorphic variant payload cases"
  | false, [ _single_payload ] ->
    Location.raise_errorf ~loc "deriving.show cannot be derived for this polymorphic variant case"

and raise_unsupported_polyvariant_inherit ~loc =
  Location.raise_errorf ~loc "deriving.show doesn't support inherited polymorphic variant rows"

and polyvariant_case field =
  match field.prf_desc with
  | Rtag (label, true, []) ->
    Exp.case (Pat.variant label.txt None) [%expr Stdlib.Format.pp_print_string fmt [%e estring ~loc ("`" ^ label.txt)]]
  | Rtag (label, false, [ payload_type ]) ->
    let payload_printer = pp_expr_of_core_type payload_type in
    Exp.case
      (Pat.variant label.txt (Some (pvar "payload")))
      [%expr
        Stdlib.Format.fprintf fmt [%e estring ~loc ("`" ^ label.txt ^ " (@[<hov>")];
        [%e payload_printer] fmt payload;
        Stdlib.Format.fprintf fmt "@])"]
  | Rtag (_label, is_constant, payload_types) ->
    raise_unsupported_polyvariant_rtag ~loc:field.prf_loc ~is_constant ~payload_types
  | Rinherit _row_type -> raise_unsupported_polyvariant_inherit ~loc:field.prf_loc

and polyvariant_printer fields =
  let cases = List.map polyvariant_case fields in
  Exp.fun_ Nolabel None (pvar "fmt") (Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases))

and pp_expr_of_core_type typ =
  let loc = typ.ptyp_loc in
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.show doesn't support payload type %s" (string_of_core_type typ)
  in
  match Attribute.get attr_printer typ with
  | Some printer_expr -> wrap_printer printer_expr
  | None ->
    if Attribute.has_flag attr_opaque typ then [%expr fun fmt _value -> Stdlib.Format.pp_print_string fmt "<opaque>"]
    else (
      match typ.ptyp_desc with
      | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
        pp_expr_of_type_constructor type_path_loc typ type_path type_args
      | Ptyp_any -> raise_unsupported typ
      | Ptyp_var type_variable_name -> Exp.ident (lid_of_string ("poly_" ^ type_variable_name))
      | Ptyp_arrow (_argument_label, _argument_type, _return_type) ->
        [%expr fun fmt _function_value -> Stdlib.Format.pp_print_string fmt "<fun>"]
      | Ptyp_tuple tuple_types -> tuple_printer tuple_types
      | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported typ
      | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported typ
      | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported typ
      | Ptyp_variant (variant_fields, Closed, _variant_labels) -> polyvariant_printer variant_fields
      | Ptyp_variant (_variant_fields, Open, _variant_labels) -> raise_unsupported typ
      | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported typ
      | Ptyp_package _package_type -> raise_unsupported typ
      | Ptyp_extension _extension -> raise_unsupported typ
      | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported typ)

and pp_expr_of_type_constructor loc typ type_path type_args =
  let raise_unsupported typ =
    Location.raise_errorf ~loc "deriving.show doesn't support payload type %s" (string_of_core_type typ)
  in
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise_unsupported typ
  | false, Lident "list", [ element_typ ] -> list_printer element_typ
  | false, Lident "option", [ element_typ ] -> option_printer element_typ
  | false, Lident "array", [ element_typ ] -> array_printer element_typ
  | false, Lident "result", [ ok_typ; error_typ ] -> result_printer ok_typ error_typ
  | false, Lident _type_name, _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (pp_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, pp_expr_of_core_type type_arg) type_args)
  | false, Lident _type_name, [] -> pp_expr_of_payload_lid loc typ type_path
  | false, Ldot (_parent_path, _type_name), _first_type_arg :: _remaining_type_args ->
    Exp.apply
      (pp_expr_of_payload_lid loc typ type_path)
      (List.map (fun type_arg -> Nolabel, pp_expr_of_core_type type_arg) type_args)
  | false, Ldot (_parent_path, _type_name), [] -> pp_expr_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise_unsupported typ

and pp_expr_of_payload_lid loc typ = function
  | Lident (("string" | "int" | "bool" | "float" | "char" | "int32" | "int64" | "bytes" | "unit") as name) ->
    primitive_printer typ name
  | Ldot (Lident "Int32", "t") -> primitive_printer typ "int32"
  | Ldot (Lident "Int64", "t") -> primitive_printer typ "int64"
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"pp" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"pp" name)) loc)
  | Lapply (_left_path, _right_path) ->
    (* Unreachable: functor-applied paths are rejected in pp_expr_of_type_constructor.
       The functor-path error is covered by test/show_snapshot_parameters.t. *)
    Location.raise_errorf ~loc "deriving.show doesn't support payload type %s" (string_of_core_type typ)

let payload_printer_arguments payload_types =
  List.mapi
    (fun i typ -> [%expr [%e pp_expr_of_core_type typ] fmt [%e Exp.ident (lid_of_string ("a" ^ string_of_int i))]])
    payload_types

let record_payload_field_printer field_decl =
  let field_name = field_decl.pld_name.txt in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  [%expr
    Stdlib.Format.fprintf fmt "@[%s =@ " [%e estring ~loc field_name];
    [%e pp_expr_of_core_type field_type] fmt [%e Exp.ident (lid_of_string ("a_" ^ field_name))];
    Stdlib.Format.fprintf fmt "@]"]

let constructor_case ~with_path ~path constructor =
  let name = constructor.pcd_name.txt in
  let printed_name = expand_path ~with_path ~path name in
  let custom_printer = Attribute.get attr_constructor_printer constructor in
  match custom_printer, constructor.pcd_args with
  | Some printer_expr, Pcstr_tuple payload_types ->
    (* Native applies the constructor printer to fmt and the payload packed as
       one value: (), the single payload, or a tuple. *)
    let payload_expr =
      match payload_types with
      | [] -> [%expr ()]
      | [ _single_payload ] -> Exp.ident (lid_of_string "a0")
      | _first_payload :: _second_payload :: _remaining_payloads ->
        Exp.tuple (List.mapi (fun i _typ -> Exp.ident (lid_of_string ("a" ^ string_of_int i))) payload_types)
    in
    Exp.case
      (constructor_pattern name (payload_pattern "a" payload_types))
      [%expr [%e wrap_printer printer_expr] fmt [%e payload_expr]]
  | Some printer_expr, Pcstr_record record_payload_fields ->
    (* Native applies the constructor printer to fmt and each field value. *)
    let field_arguments =
      List.map
        (fun field_decl -> Nolabel, Exp.ident (lid_of_string ("a_" ^ field_decl.pld_name.txt)))
        record_payload_fields
    in
    Exp.case
      (constructor_pattern name (Some (record_payload_pattern "a_" record_payload_fields)))
      (Exp.apply (wrap_printer printer_expr) ((Nolabel, [%expr fmt]) :: field_arguments))
  | None, Pcstr_tuple [] ->
    Exp.case (constructor_pattern name None) [%expr Stdlib.Format.pp_print_string fmt [%e estring ~loc printed_name]]
  | None, Pcstr_tuple [ payload_type ] ->
    Exp.case
      (constructor_pattern name (payload_pattern "a" [ payload_type ]))
      [%expr
        Stdlib.Format.fprintf fmt [%e estring ~loc ("(@[<2>" ^ printed_name ^ "@ ")];
        [%e pp_expr_of_core_type payload_type] fmt a0;
        Stdlib.Format.fprintf fmt "@])"]
  | None, Pcstr_tuple payload_types ->
    Exp.case
      (constructor_pattern name (payload_pattern "a" payload_types))
      (print_between
         ~before:("(@[<2>" ^ printed_name ^ " (@,")
         ~sep:",@ " ~after:"@,))@]"
         (payload_printer_arguments payload_types))
  | None, Pcstr_record record_payload_fields ->
    Exp.case
      (constructor_pattern name (Some (record_payload_pattern "a_" record_payload_fields)))
      (print_between
         ~before:("@[<2>" ^ printed_name ^ " {@,")
         ~sep:";@ " ~after:"@]}"
         (List.map record_payload_field_printer record_payload_fields))

let expr_of_variant ~with_path ~path constructors =
  let cases = List.map (constructor_case ~with_path ~path) constructors in
  Exp.fun_ Nolabel None (pvar "fmt") (Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases))

let record_field_printer ~with_path ~path index field_decl =
  let field_name = field_decl.pld_name.txt in
  let printed_name =
    match index with
    | 0 -> expand_path ~with_path ~path field_name
    | _later_field_index -> field_name
  in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  let field_lid = mkloc (Lident field_name) field_decl.pld_name.loc in
  [%expr
    Stdlib.Format.fprintf fmt "@[%s =@ " [%e estring ~loc printed_name];
    [%e pp_expr_of_core_type field_type] fmt [%e Exp.field (Exp.ident (lid_of_string "x")) field_lid];
    Stdlib.Format.fprintf fmt "@]"]

let expr_of_record ~with_path ~path fields =
  let field_printers = List.mapi (record_field_printer ~with_path ~path) fields in
  Exp.fun_ Nolabel None (pvar "fmt")
    (Exp.fun_ Nolabel None (pvar "x") (print_between ~before:"@[<2>{ " ~sep:";@ " ~after:"@ }@]" field_printers))

(* Aliases whose printer is not already a lambda (Foo.pp, pp_foo poly_a,
   poly_a) are eta-expanded so the binding stays a valid let-rec right-hand
   side. *)
let eta_expand_printer printer_expr =
  if is_syntactic_function printer_expr then printer_expr else [%expr fun fmt x -> [%e printer_expr] fmt x]

(* ---- String rendering for [show] ----------------------------------------

   In Melange, referencing Stdlib.Format at all pulls the large
   CamlinternalFormat machinery into the JS bundle (Format calls it
   internally, so even direct pp_print_* calls retain it). [show] is
   therefore generated as plain string building whenever the type allows it:
   frontend code that only calls [show] never links Format, while [pp] stays
   Format-based for native parity, [%a] composition, and [@printer] support.

   String rendering produces exactly the strings [pp] renders for values that
   fit Format's margin; longer values stay on a single line instead of
   wrapping. Composition happens through other types' [show] functions.

   [Formatter_required] aborts string rendering where a formatter is
   genuinely needed — type parameters (the callbacks are printers), custom
   [@printer] attributes, and applications of parameterized types — in which
   case [show] falls back to [Stdlib.Format.asprintf "%a" pp]. Payload shapes
   that [show] does not support at all are rejected earlier, when the [pp]
   expression is generated. *)
exception Formatter_required

(* The pure-stdlib equivalents of the %d/%S/%C/%F/... conversions [pp] uses;
   each matches the Format output exactly (%F's infinity/nan spelling
   included). *)
let string_primitive_renderer typ name =
  let loc = typ.ptyp_loc in
  match name with
  | "unit" -> [%expr fun () -> "()"]
  | "int" -> [%expr string_of_int]
  | "bool" -> [%expr string_of_bool]
  | "string" -> [%expr fun x -> "\"" ^ String.escaped x ^ "\""]
  | "char" -> [%expr fun x -> "'" ^ Char.escaped x ^ "'"]
  | "bytes" -> [%expr fun x -> "\"" ^ String.escaped (Bytes.to_string x) ^ "\""]
  | "int32" -> [%expr fun x -> Int32.to_string x ^ "l"]
  | "int64" -> [%expr fun x -> Int64.to_string x ^ "L"]
  | "float" ->
    [%expr
      fun x ->
        match classify_float x with
        | FP_nan -> "nan"
        | FP_infinite -> if x > 0.0 then "infinity" else "-infinity"
        | _finite_class -> string_of_float x]
  | _other_name ->
    (* Unreachable: string_renderer_of_payload_lid only dispatches the names
       above. *)
    Location.raise_errorf ~loc "deriving.show doesn't support payload type %s" (string_of_core_type typ)

(* before ^ part1 ^ separator ^ part2 ^ ... ^ after, as one expression. *)
let concat_rendered ~before ~separator ~after rendered_parts =
  let pieces =
    (estring ~loc before :: separated ~separator:(estring ~loc separator) rendered_parts) @ [ estring ~loc after ]
  in
  match pieces with
  | [] -> estring ~loc ""
  | first :: rest -> List.fold_left (fun acc piece -> [%expr [%e acc] ^ [%e piece]]) first rest

let rec string_renderer_of_core_type typ =
  let loc = typ.ptyp_loc in
  match Attribute.get attr_printer typ with
  | Some _custom_printer -> raise Formatter_required
  | None ->
    if Attribute.has_flag attr_opaque typ then [%expr fun _value -> "<opaque>"]
    else (
      match typ.ptyp_desc with
      | Ptyp_constr ({ txt = type_path; loc = type_path_loc }, type_args) ->
        string_renderer_of_type_constructor type_path_loc typ type_path type_args
      | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> [%expr fun _function_value -> "<fun>"]
      | Ptyp_tuple tuple_types -> string_tuple_renderer tuple_types
      | Ptyp_variant (variant_fields, Closed, _variant_labels) -> string_polyvariant_renderer variant_fields
      | Ptyp_var _type_variable_name -> raise Formatter_required
      | _other_type -> raise Formatter_required)

and string_renderer_of_type_constructor loc typ type_path type_args =
  match has_functor_application type_path, type_path, type_args with
  | true, _type_path, _type_args -> raise Formatter_required
  | false, Lident "list", [ element_typ ] ->
    [%expr fun x -> "[" ^ String.concat "; " (List.map [%e string_renderer_of_core_type element_typ] x) ^ "]"]
  | false, Lident "option", [ element_typ ] ->
    [%expr
      fun x ->
        match x with
        | None -> "None"
        | Some value -> "(Some " ^ [%e string_renderer_of_core_type element_typ] value ^ ")"]
  | false, Lident "array", [ element_typ ] ->
    [%expr
      fun x ->
        "[|" ^ String.concat "; " (Array.to_list (Array.map [%e string_renderer_of_core_type element_typ] x)) ^ "|]"]
  | false, Lident "result", [ ok_typ; error_typ ] ->
    [%expr
      fun x ->
        match x with
        | Ok value -> "(Ok " ^ [%e string_renderer_of_core_type ok_typ] value ^ ")"
        | Error error -> "(Error " ^ [%e string_renderer_of_core_type error_typ] error ^ ")"]
  | false, (Lident _type_name | Ldot (_, _type_name)), _first_type_arg :: _remaining_type_args ->
    (* Applications of parameterized types compose through pp printers. *)
    raise Formatter_required
  | false, (Lident _type_name | Ldot (_, _type_name)), [] -> string_renderer_of_payload_lid loc typ type_path
  | false, Lapply (_left_path, _right_path), _type_args -> raise Formatter_required

and string_renderer_of_payload_lid loc typ = function
  | Lident (("string" | "int" | "bool" | "float" | "char" | "int32" | "int64" | "bytes" | "unit") as name) ->
    string_primitive_renderer typ name
  | Ldot (Lident "Int32", "t") -> string_primitive_renderer typ "int32"
  | Ldot (Lident "Int64", "t") -> string_primitive_renderer typ "int64"
  | Lident name -> Exp.ident (mkloc (Lident (mangle_name ~prefix:"show" name)) loc)
  | Ldot (path, name) -> Exp.ident (mkloc (Ldot (path, mangle_name ~prefix:"show" name)) loc)
  | Lapply (_left_path, _right_path) -> raise Formatter_required

and string_tuple_renderer tuple_types =
  let pattern, expressions = tuple_bindings "a" tuple_types in
  let rendered_parts =
    List.map2
      (fun typ expression -> [%expr [%e string_renderer_of_core_type typ] [%e expression]])
      tuple_types expressions
  in
  Exp.fun_ Nolabel None pattern (concat_rendered ~before:"(" ~separator:", " ~after:")" rendered_parts)

and string_polyvariant_case field =
  match field.prf_desc with
  | Rtag (label, true, []) -> Exp.case (Pat.variant label.txt None) (estring ~loc ("`" ^ label.txt))
  | Rtag (label, false, [ payload_type ]) ->
    Exp.case
      (Pat.variant label.txt (Some (pvar "payload")))
      [%expr [%e estring ~loc ("`" ^ label.txt ^ " (")] ^ [%e string_renderer_of_core_type payload_type] payload ^ ")"]
  | Rtag (_label, _is_constant, _payload_types) -> raise Formatter_required
  | Rinherit _row_type -> raise Formatter_required

and string_polyvariant_renderer fields =
  let cases = List.map string_polyvariant_case fields in
  Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases)

let string_record_payload_field_renderer field_decl =
  let field_name = field_decl.pld_name.txt in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  [%expr
    [%e estring ~loc (field_name ^ " = ")]
    ^ [%e string_renderer_of_core_type field_type] [%e Exp.ident (lid_of_string ("a_" ^ field_name))]]

let string_constructor_case ~with_path ~path constructor =
  (match Attribute.get attr_constructor_printer constructor with
  | None -> ()
  | Some _custom_printer -> raise Formatter_required);
  let name = constructor.pcd_name.txt in
  let printed_name = expand_path ~with_path ~path name in
  match constructor.pcd_args with
  | Pcstr_tuple [] -> Exp.case (constructor_pattern name None) (estring ~loc printed_name)
  | Pcstr_tuple [ payload_type ] ->
    Exp.case
      (constructor_pattern name (payload_pattern "a" [ payload_type ]))
      [%expr [%e estring ~loc ("(" ^ printed_name ^ " ")] ^ [%e string_renderer_of_core_type payload_type] a0 ^ ")"]
  | Pcstr_tuple payload_types ->
    let rendered_parts =
      List.mapi
        (fun i typ ->
          [%expr [%e string_renderer_of_core_type typ] [%e Exp.ident (lid_of_string ("a" ^ string_of_int i))]])
        payload_types
    in
    Exp.case
      (constructor_pattern name (payload_pattern "a" payload_types))
      (concat_rendered ~before:("(" ^ printed_name ^ " (") ~separator:", " ~after:"))" rendered_parts)
  | Pcstr_record record_payload_fields ->
    Exp.case
      (constructor_pattern name (Some (record_payload_pattern "a_" record_payload_fields)))
      (concat_rendered ~before:(printed_name ^ " {") ~separator:"; " ~after:"}"
         (List.map string_record_payload_field_renderer record_payload_fields))

let string_expr_of_variant ~with_path ~path constructors =
  let cases = List.map (string_constructor_case ~with_path ~path) constructors in
  Exp.fun_ Nolabel None (pvar "x") (Exp.match_ [%expr x] cases)

let string_record_field_renderer ~with_path ~path index field_decl =
  let field_name = field_decl.pld_name.txt in
  let printed_name =
    match index with
    | 0 -> expand_path ~with_path ~path field_name
    | _later_field_index -> field_name
  in
  let field_type =
    { field_decl.pld_type with ptyp_attributes = field_decl.pld_type.ptyp_attributes @ field_decl.pld_attributes }
  in
  let field_lid = mkloc (Lident field_name) field_decl.pld_name.loc in
  [%expr
    [%e estring ~loc (printed_name ^ " = ")]
    ^ [%e string_renderer_of_core_type field_type] [%e Exp.field (Exp.ident (lid_of_string "x")) field_lid]]

let string_expr_of_record ~with_path ~path fields =
  let rendered_fields = List.mapi (string_record_field_renderer ~with_path ~path) fields in
  Exp.fun_ Nolabel None (pvar "x") (concat_rendered ~before:"{ " ~separator:"; " ~after:" }" rendered_fields)

let eta_expand_string_renderer renderer_expr =
  if is_syntactic_function renderer_expr then renderer_expr else [%expr fun x -> [%e renderer_expr] x]

(* The string-rendering [show] for a whole declaration, or None when a
   formatter is required and [show] must fall back to asprintf over [pp]. *)
let string_show_of_type ~with_path ~path type_decl =
  match type_decl.ptype_params, type_decl.ptype_kind, type_decl.ptype_manifest with
  | _first_type_param :: _remaining_type_params, _type_kind, _type_manifest -> None
  | [], Ptype_variant constructors, _type_manifest ->
    (try Some (string_expr_of_variant ~with_path ~path constructors) with Formatter_required -> None)
  | [], Ptype_record record_fields, _type_manifest ->
    (try Some (string_expr_of_record ~with_path ~path record_fields) with Formatter_required -> None)
  | [], Ptype_abstract, Some manifest_type ->
    (try Some (eta_expand_string_renderer (string_renderer_of_core_type manifest_type))
     with Formatter_required -> None)
  | [], _other_kind, _type_manifest -> None

let str_of_type ~deriver ~with_path ~path
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
  let path = path_of_type_decl ~path type_decl in
  let pp_exp =
    match ptype_kind, ptype_manifest with
    | Ptype_variant constructors, _type_manifest -> expr_of_variant ~with_path ~path constructors
    | Ptype_record record_fields, _type_manifest -> expr_of_record ~with_path ~path record_fields
    | Ptype_abstract, None -> Location.raise_errorf ~loc "deriving.%s doesn't support abstract types" deriver
    | Ptype_abstract, Some manifest_type -> eta_expand_printer (pp_expr_of_core_type manifest_type)
    | Ptype_open, _type_manifest -> Location.raise_errorf ~loc "deriving.%s doesn't support open types" deriver
  in
  let with_type_parameters expr =
    List.fold_right
      (fun (type_param, _variance_and_injectivity) acc ->
        Exp.fun_ Nolabel None (pvar (type_parameter_printer_name type_param)) acc)
      ptype_params expr
  in
  let applied_pp =
    List.fold_left
      (fun acc (type_param, _variance_and_injectivity) ->
        Exp.apply acc [ Nolabel, Exp.ident (lid_of_string (type_parameter_printer_name type_param)) ])
      (Exp.ident (lid_of_string (pp_name type_decl)))
      ptype_params
  in
  let show_exp =
    match string_show_of_type ~with_path ~path type_decl with
    | Some string_show_exp -> string_show_exp
    | None -> with_type_parameters [%expr fun x -> Stdlib.Format.asprintf "%a" [%e applied_pp] x]
  in
  [
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (pp_name type_decl)) (pp_type_of_decl type_decl))
      (with_type_parameters pp_exp);
    Vb.mk
      ~attrs:[ warning_attribute "-39" ]
      (Pat.constraint_ (pvar (show_name type_decl)) (show_type_of_decl type_decl))
      show_exp;
  ]

let sig_of_type type_decl =
  [
    Sig.value (Val.mk (mknoloc (pp_name type_decl)) (pp_type_of_decl type_decl));
    Sig.value (Val.mk (mknoloc (show_name type_decl)) (show_type_of_decl type_decl));
  ]

(* The args value cannot be shared between the str and sig generators: it would
   get a weak type from the first use. *)
let deriver_args () = Deriving.Args.(empty +> arg "with_path" (Ast_pattern.ebool __))

let str_type_decl ~deriver =
  Deriving.Generator.V2.make (deriver_args ()) (fun ~ctxt (_rec_flag, type_decls) with_path ->
    let with_path =
      match with_path with
      | None -> true
      | Some with_path -> with_path
    in
    let path = module_path_of_context ctxt in
    [ pstr_value ~loc Recursive (List.concat (List.map (str_of_type ~deriver ~with_path ~path) type_decls)) ])

let sig_type_decl =
  Deriving.Generator.V2.make (deriver_args ()) (fun ~ctxt:_expansion_context (_rec_flag, type_decls) _with_path ->
    List.concat (List.map sig_of_type type_decls))

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl:(str_type_decl ~deriver) ~sig_type_decl
