import gleam/order
import gleam/string

pub type Equality(a) =
  fn(a, a) -> Bool

pub fn i_equal(a: Int, b: Int) {
  a == b
}

pub fn f_equal(a: Float, b: Float) {
  a == b
}

pub fn str_equal(a: String, b: String) {
  case string.compare(a, b) {
    order.Eq -> True
    _ -> False
  }
}
