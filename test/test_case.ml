type t = {
  name : string;
  run : assert_bool_equal:(bool -> bool -> unit) -> unit;
}
