module All_field_kinds = struct
  (* Native's `a`: option, list, default, split, plain — no [@main], so the
     constructor closes with a unit argument. *)
  type t = {
    a1 : int option;
    a2 : int list;
    a3 : int; [@default 42]
    a4s : int * int list; [@split]
    a5 : int;
  }
  [@@deriving make]

  let run ~assert_bool_equal =
    assert_bool_equal (make ~a4:2 ~a5:1 () = { a1 = None; a2 = []; a3 = 42; a4s = 2, []; a5 = 1 }) true;
    assert_bool_equal
      (make ~a1:1 ~a2:[ 2 ] ~a3:3 ~a4:4 ~a4s:[ 5 ] ~a5:6 ()
      = { a1 = Some 1; a2 = [ 2 ]; a3 = 3; a4s = 4, [ 5 ]; a5 = 6 })
      true
end

module Main_field = struct
  (* Native's `b`: a [@main] field becomes the final positional argument. *)
  type t = {
    b1 : int option;
    b2 : int list;
    b3 : int; [@default 42]
    b4s : int * int list; [@split]
    b5 : int; [@main]
  }
  [@@deriving make]

  let run ~assert_bool_equal =
    assert_bool_equal (make ~b4:2 1 = { b1 = None; b2 = []; b3 = 42; b4s = 2, []; b5 = 1 }) true;
    assert_bool_equal
      (make ~b1:1 ~b2:[ 2 ] ~b3:3 ~b4:4 ~b4s:[ 5 ] 6 = { b1 = Some 1; b2 = [ 2 ]; b3 = 3; b4s = 4, [ 5 ]; b5 = 6 })
      true
end

module No_unit = struct
  (* Native's `c`: no optionals and no [@main], so no trailing unit. *)
  type t = {
    c1 : int;
    c2 : string;
  }
  [@@deriving make]

  let run ~assert_bool_equal = assert_bool_equal (make ~c1:0 ~c2:"" = { c1 = 0; c2 = "" }) true
end

module Argument_order = struct
  (* Native's M2: arguments follow field declaration order. *)
  type t = {
    first : int;
    second : int;
  }
  [@@deriving make]

  let run ~assert_bool_equal = assert_bool_equal (make ~first:1 ~second:2 = { first = 1; second = 2 }) true
end

module Option_and_list_defaults = struct
  type t = {
    name : string;
    tags : string list;
    parent : string option;
  }
  [@@deriving make]

  let run ~assert_bool_equal =
    assert_bool_equal (make ~name:"a" () = { name = "a"; tags = []; parent = None }) true;
    assert_bool_equal
      (make ~name:"a" ~tags:[ "x"; "y" ] ~parent:"p" () = { name = "a"; tags = [ "x"; "y" ]; parent = Some "p" })
      true
end

module Default_beats_option = struct
  type t = { value : int option [@default Some 7] } [@@deriving make]

  let run ~assert_bool_equal =
    assert_bool_equal (make () = { value = Some 7 }) true;
    assert_bool_equal (make ~value:None () = { value = None }) true
end

module Parameterized = struct
  type 'a t = {
    value : 'a;
    extras : 'a list;
  }
  [@@deriving make]

  let run ~assert_bool_equal =
    assert_bool_equal (make ~value:1 () = { value = 1; extras = [] }) true;
    assert_bool_equal (make ~value:"a" ~extras:[ "b" ] () = { value = "a"; extras = [ "b" ] }) true
end

module Naming = struct
  type status = {
    code : int;
    label : string;
  }
  [@@deriving make]

  let run ~assert_bool_equal = assert_bool_equal (make_status ~code:1 ~label:"ok" = { code = 1; label = "ok" }) true
end

module Recursive_group = struct
  (* Native #272: make generated only for the record member; the alias
     sibling is skipped. *)
  type principle = {
    prt1 : int;
    prt2 : secondary;
  }

  and secondary = string [@@deriving make]

  let run ~assert_bool_equal = assert_bool_equal (make_principle ~prt1:0 ~prt2:"" = { prt1 = 0; prt2 = "" }) true
end

module Module_signature = struct
  module M : sig
    type t = {
      x : int;
      ys : int list;
    }
    [@@deriving make]
  end = struct
    type t = {
      x : int;
      ys : int list;
    }
    [@@deriving make]
  end

  let run ~assert_bool_equal =
    assert_bool_equal (M.make ~x:1 () = { M.x = 1; ys = [] }) true;
    assert_bool_equal (M.make ~x:1 ~ys:[ 2 ] () = { M.x = 1; ys = [ 2 ] }) true
end

let all : Test_case.t list =
  [
    { name = "all_field_kinds"; run = All_field_kinds.run };
    { name = "main_field"; run = Main_field.run };
    { name = "no_unit"; run = No_unit.run };
    { name = "argument_order"; run = Argument_order.run };
    { name = "option_and_list_defaults"; run = Option_and_list_defaults.run };
    { name = "default_beats_option"; run = Default_beats_option.run };
    { name = "parameterized"; run = Parameterized.run };
    { name = "naming"; run = Naming.run };
    { name = "recursive_group"; run = Recursive_group.run };
    { name = "module_signature"; run = Module_signature.run };
  ]
