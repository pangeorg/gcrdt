import gcrdt/vtime
import gleam/dict
import gleam/option.{None, Some}

// last write wins register
pub opaque type Lww(a) {
  Lww(value: dict.Dict(Int, a), stamp: vtime.VTime)
}

pub fn new() {
  Lww(value: dict.new(), stamp: vtime.new())
}

pub fn value(lww: Lww(a)) {
  case vtime.max(lww.stamp) {
    Some(id) -> {
      lww.value |> dict.get(id)
    }
    None -> Error(Nil)
  }
}

pub fn set(lww: Lww(a), value: a, id: Int) {
  let value = lww.value |> dict.insert(id, value)
  Lww(value:, stamp: vtime.inc(lww.stamp, id))
}

pub fn merge(a: Lww(a), b: Lww(a)) {
  case vtime.compare(a.stamp, b.stamp) {
    vtime.Gt -> a
    _ -> b
  }
}
