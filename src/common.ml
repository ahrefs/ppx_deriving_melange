open Ppxlib
open Parsetree
open Ast_helper
open Ast_builder.Default

let loc = !default_loc
let mkloc txt loc = { txt; loc }
let mknoloc txt = mkloc txt !default_loc
let pvar name = Pat.var (mknoloc name)
let lid_of_string s = mknoloc (Longident.parse s)

let warning_attribute message =
  {
    attr_name = mkloc "ocaml.warning" loc;
    attr_payload = PStr [ pstr_eval ~loc (estring ~loc message) [] ];
    attr_loc = loc;
  }

let mangle_type_decl ~prefix type_decl =
  match type_decl.ptype_name.txt with
  | "t" -> prefix
  | name -> prefix ^ "_" ^ name

let mangle_name ~prefix = function
  | "t" -> prefix
  | name -> prefix ^ "_" ^ name

let core_type_of_type_decl
  {
    ptype_name = name;
    ptype_params;
    ptype_cstrs = _type_constraints;
    ptype_kind = _type_kind;
    ptype_private = _type_private;
    ptype_manifest = _type_manifest;
    ptype_attributes = _type_attributes;
    ptype_loc = _type_loc;
  } =
  Typ.constr (mkloc (Lident name.txt) name.loc) (List.map fst ptype_params)

let type_parameter_name ~deriver typ =
  let raise_unsupported () =
    Location.raise_errorf ~loc:typ.ptyp_loc "deriving.%s doesn't support non-variable type parameters" deriver
  in
  match typ.ptyp_desc with
  | Ptyp_var name -> name
  | Ptyp_any -> raise_unsupported ()
  | Ptyp_arrow (_argument_label, _argument_type, _return_type) -> raise_unsupported ()
  | Ptyp_tuple _tuple_types -> raise_unsupported ()
  | Ptyp_constr (_type_path, _type_args) -> raise_unsupported ()
  | Ptyp_object (_object_fields, _object_closed_flag) -> raise_unsupported ()
  | Ptyp_class (_class_path, _class_type_args) -> raise_unsupported ()
  | Ptyp_alias (_aliased_type, _alias_name) -> raise_unsupported ()
  | Ptyp_variant (_variant_fields, _variant_closed_flag, _variant_labels) -> raise_unsupported ()
  | Ptyp_poly (_type_variables, _body_type) -> raise_unsupported ()
  | Ptyp_package _package_type -> raise_unsupported ()
  | Ptyp_extension _extension -> raise_unsupported ()
  | Ptyp_open (_open_declaration, _opened_type) -> raise_unsupported ()

let rec has_functor_application = function
  | Lident _name -> false
  | Ldot (path, _name) -> has_functor_application path
  | Lapply (_left, _right) -> true

let tuple_bindings prefix tuple_types =
  let patterns, expressions =
    List.mapi
      (fun i _tuple_type ->
        let name = prefix ^ string_of_int i in
        pvar name, Exp.ident (lid_of_string name))
      tuple_types
    |> List.split
  in
  Pat.tuple patterns, expressions

let constructor_pattern name payload = Pat.construct (lid_of_string name) payload

let payload_pattern prefix payload_types =
  match payload_types with
  | [] -> None
  | [ _ ] -> Some (pvar (prefix ^ "0"))
  | _ -> Some (Pat.tuple (List.mapi (fun i _typ -> pvar (prefix ^ string_of_int i)) payload_types))

let record_payload_pattern prefix fields =
  let field_patterns =
    List.map
      (fun field_decl ->
        let field_name = field_decl.pld_name in
        let field_lid = mkloc (Lident field_name.txt) field_name.loc in
        field_lid, pvar (prefix ^ field_name.txt))
      fields
  in
  Pat.record field_patterns Closed

(* Whether the expression is a syntactic function, i.e. a valid right-hand side
   of a let-rec binding. Derivers eta-expand alias expressions that fail this
   check: a bare reference or application of a function from the same recursive
   binding group (type b = a, type t = float poly_abs) is rejected by the
   compiler. *)
let is_syntactic_function expr =
  match expr.pexp_desc with
  | Pexp_function (_parameters, _type_constraint, _body) -> true
  | _other_expression -> false

(* Conservative over-approximation of the free type variables: `as`-alias names
   and `Ptyp_poly` binders are counted too. Over-collecting only means a type is
   traversed (and possibly rejected with a clear error) instead of collapsing to
   a no-op, which is the safe direction. *)
let free_type_variables typ =
  let collector =
    object
      inherit [string list] Ast_traverse.fold as super

      method! core_type typ acc =
        let acc =
          match typ.ptyp_desc with
          | Ptyp_var name -> name :: acc
          | Ptyp_alias (_aliased_type, name) -> name.txt :: acc
          | _ -> acc
        in
        super#core_type typ acc
    end
  in
  collector#core_type typ []

let reject_free_type_variables ~deriver typ =
  match List.sort_uniq String.compare (free_type_variables typ) with
  | [] -> ()
  | _first_free_variable :: _remaining_free_variables as free_variables ->
    let named = String.concat ", " (List.map (fun name -> "'" ^ name) free_variables) in
    Location.raise_errorf ~loc:typ.ptyp_loc "deriving.%s doesn't support free type variables (%s) in [%%%s: ...]"
      deriver named deriver
