open Ppxlib
open Asttypes
open Parsetree
open Ast_helper
open Ast_builder.Default
open Common

let deriver = "make"
let make_name type_decl = mangle_type_decl ~prefix:"make" type_decl

(* Attributes are declared in both the plain and namespaced spellings (as eq
   does for [@equal]/[@deriving.eq.equal]) and on both the label-declaration
   and core-type contexts, since a record-field attribute can attach at either
   point. Lookups check the label contexts before the core-type contexts,
   matching native's get_label_attribute order. *)
let attr_default_label =
  Attribute.declare "default" Attribute.Context.label_declaration Ast_pattern.(single_expr_payload __) Fun.id

let attr_default_label_ns =
  Attribute.declare "deriving.make.default" Attribute.Context.label_declaration
    Ast_pattern.(single_expr_payload __)
    Fun.id

let attr_default_core_type =
  Attribute.declare "default" Attribute.Context.core_type Ast_pattern.(single_expr_payload __) Fun.id

let attr_default_core_type_ns =
  Attribute.declare "deriving.make.default" Attribute.Context.core_type Ast_pattern.(single_expr_payload __) Fun.id

let attr_main_label = Attribute.declare_flag "main" Attribute.Context.label_declaration
let attr_main_label_ns = Attribute.declare_flag "deriving.make.main" Attribute.Context.label_declaration
let attr_main_core_type = Attribute.declare_flag "main" Attribute.Context.core_type
let attr_main_core_type_ns = Attribute.declare_flag "deriving.make.main" Attribute.Context.core_type
let attr_split_label = Attribute.declare_flag "split" Attribute.Context.label_declaration
let attr_split_label_ns = Attribute.declare_flag "deriving.make.split" Attribute.Context.label_declaration
let attr_split_core_type = Attribute.declare_flag "split" Attribute.Context.core_type
let attr_split_core_type_ns = Attribute.declare_flag "deriving.make.split" Attribute.Context.core_type

let default_attribute field_decl =
  match Attribute.get attr_default_label field_decl with
  | Some _ as default_expr -> default_expr
  | None ->
  match Attribute.get attr_default_label_ns field_decl with
  | Some _ as default_expr -> default_expr
  | None ->
  match Attribute.get attr_default_core_type field_decl.pld_type with
  | Some _ as default_expr -> default_expr
  | None -> Attribute.get attr_default_core_type_ns field_decl.pld_type

let has_main field_decl =
  Attribute.has_flag attr_main_label field_decl
  || Attribute.has_flag attr_main_label_ns field_decl
  || Attribute.has_flag attr_main_core_type field_decl.pld_type
  || Attribute.has_flag attr_main_core_type_ns field_decl.pld_type

let has_split field_decl =
  Attribute.has_flag attr_split_label field_decl
  || Attribute.has_flag attr_split_label_ns field_decl
  || Attribute.has_flag attr_split_core_type field_decl.pld_type
  || Attribute.has_flag attr_split_core_type_ns field_decl.pld_type

let raise_split_error loc =
  Location.raise_errorf ~loc "deriving.make [@split] requires a field of type 'a * 'b list whose name ends in 's'"

(* [@main] fields are separated out before any other argument handling: a
   [@main] field becomes the final positional argument and its other
   attributes are ignored. Two or more [@main] fields is an error. *)
let find_main labels =
  let main_labels, regular_labels = List.partition has_main labels in
  match main_labels with
  | [] -> None, regular_labels
  | [ main_label ] -> Some main_label, regular_labels
  | _first_main :: second_main :: _remaining_mains ->
    Location.raise_errorf ~loc:second_main.pld_loc "deriving.make doesn't support duplicate [@main] annotations"

let is_list_type typ =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "list"; _ }, [ _element_type ]) -> true
  | _other_type -> false

let is_optional_field field_decl =
  match default_attribute field_decl with
  | Some _default_expr -> true
  | None ->
    has_split field_decl
    ||
      (match field_decl.pld_type.ptyp_desc with
      | Ptyp_constr ({ txt = Lident ("option" | "list"); _ }, [ _element_type ]) -> true
      | _other_type -> false)

let split_components field_decl =
  match field_decl.pld_type.ptyp_desc with
  | Ptyp_tuple [ singular_type; list_type ] when is_list_type list_type -> Some (singular_type, list_type)
  | _other_type -> None

let singular_name name =
  match name.[String.length name - 1] with
  | 's' -> Some (String.sub name 0 (String.length name - 1))
  | _other_char -> None

(* Each field wraps another labelled/optional argument around the accumulator,
   folded in reverse so arguments end up in field-declaration order. *)
let add_str_label_arg accum field_decl =
  let name = field_decl.pld_name.txt in
  let loc = field_decl.pld_loc in
  match default_attribute field_decl with
  | Some default_expr -> Exp.fun_ (Optional name) (Some default_expr) (pvar name) accum
  | None ->
    if has_split field_decl then (
      match split_components field_decl, singular_name name with
      | Some (_singular_type, _list_type), Some singular ->
        Exp.fun_ (Labelled singular) None (pvar singular)
          (Exp.fun_ (Optional name)
             (Some [%expr []])
             (pvar name)
             (Exp.let_ Nonrecursive
                [ Vb.mk (pvar name) (Exp.tuple [ Exp.ident (lid_of_string singular); Exp.ident (lid_of_string name) ]) ]
                accum))
      | _unmatched_split -> raise_split_error loc)
    else (
      match field_decl.pld_type.ptyp_desc with
      | Ptyp_constr ({ txt = Lident "list"; _ }, [ _element_type ]) ->
        Exp.fun_ (Optional name) (Some [%expr []]) (pvar name) accum
      | Ptyp_constr ({ txt = Lident "option"; _ }, [ _element_type ]) -> Exp.fun_ (Optional name) None (pvar name) accum
      | _other_type -> Exp.fun_ (Labelled name) None (pvar name) accum)

let record_of_labels labels =
  let fields =
    List.map
      (fun field_decl ->
        let name = field_decl.pld_name in
        mkloc (Lident name.txt) name.loc, Exp.ident (lid_of_string name.txt))
      labels
  in
  Exp.record fields None

let str_of_record_type labels =
  let record_expr = record_of_labels labels in
  let main, regular_labels = find_main labels in
  let has_optional = List.exists is_optional_field regular_labels in
  let closing =
    match main with
    | Some { pld_name = { txt = name; _ }; _ } -> Exp.fun_ Nolabel None (pvar name) record_expr
    | None -> if has_optional then Exp.fun_ Nolabel None [%pat? ()] record_expr else record_expr
  in
  List.fold_left add_str_label_arg closing (List.rev regular_labels)

let add_sig_label_arg accum field_decl =
  let name = field_decl.pld_name.txt in
  let loc = field_decl.pld_loc in
  match default_attribute field_decl with
  | Some _default_expr -> Typ.arrow (Optional name) field_decl.pld_type accum
  | None ->
    if has_split field_decl then (
      match split_components field_decl, singular_name name with
      | Some (singular_type, list_type), Some singular ->
        Typ.arrow (Labelled singular) singular_type (Typ.arrow (Optional name) list_type accum)
      | _unmatched_split -> raise_split_error loc)
    else (
      match field_decl.pld_type.ptyp_desc with
      | Ptyp_constr ({ txt = Lident "list"; _ }, [ _element_type ]) ->
        Typ.arrow (Optional name) field_decl.pld_type accum
      | Ptyp_constr ({ txt = Lident "option"; _ }, [ element_type ]) -> Typ.arrow (Optional name) element_type accum
      | _other_type -> Typ.arrow (Labelled name) field_decl.pld_type accum)

let sig_of_record_type ~result_type labels =
  let main, regular_labels = find_main labels in
  let has_optional = List.exists is_optional_field regular_labels in
  let base =
    match main with
    | Some { pld_type; _ } -> Typ.arrow Nolabel pld_type result_type
    | None -> if has_optional then Typ.arrow Nolabel [%type: unit] result_type else result_type
  in
  List.fold_left add_sig_label_arg base (List.rev regular_labels)

let records_only_error loc = loc, Printf.sprintf "deriving.%s can be derived only for record types" deriver

let str_of_type type_decl =
  let loc = type_decl.ptype_loc in
  match type_decl.ptype_kind with
  | Ptype_record labels -> Ok (Vb.mk (pvar (make_name type_decl)) (str_of_record_type labels))
  | Ptype_variant _constructors -> Error (records_only_error loc)
  | Ptype_abstract -> Error (records_only_error loc)
  | Ptype_open -> Error (records_only_error loc)

let sig_of_type type_decl =
  let loc = type_decl.ptype_loc in
  match type_decl.ptype_kind with
  | Ptype_record labels ->
    let result_type = core_type_of_type_decl type_decl in
    Ok (Sig.value (Val.mk (mknoloc (make_name type_decl)) (sig_of_record_type ~result_type labels)))
  | Ptype_variant _constructors -> Error (records_only_error loc)
  | Ptype_abstract -> Error (records_only_error loc)
  | Ptype_open -> Error (records_only_error loc)

(* Ppxlib does not track which declaration of a recursive group the
   [@@deriving make] attribute was attached to, so — like native
   ppx_deriving (issue #272) — we generate make for the record members and
   silently skip non-record members, as long as at least one member is a
   record. If every member fails, the first error is raised. *)
let partition_results results =
  List.fold_right
    (fun result (oks, errors) ->
      match result with
      | Ok value -> value :: oks, errors
      | Error error -> oks, error :: errors)
    results ([], [])

let str_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    let oks, errors = partition_results (List.map str_of_type type_decls) in
    match oks with
    | _first_ok :: _remaining_oks -> [ pstr_value ~loc Nonrecursive oks ]
    | [] ->
    match errors with
    | (error_loc, message) :: _remaining_errors -> Location.raise_errorf ~loc:error_loc "%s" message
    | [] -> [])

let sig_type_decl =
  Deriving.Generator.V2.make Deriving.Args.empty (fun ~ctxt:_expansion_context (_rec_flag, type_decls) ->
    let oks, errors = partition_results (List.map sig_of_type type_decls) in
    match oks with
    | _first_ok :: _remaining_oks -> oks
    | [] ->
    match errors with
    | (error_loc, message) :: _remaining_errors -> Location.raise_errorf ~loc:error_loc "%s" message
    | [] -> [])

let deriving : Deriving.t = Deriving.add deriver ~str_type_decl ~sig_type_decl
