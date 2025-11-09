import gcrdt/icounter
import gcrdt/replica
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/order

pub type VOrd {
  // <
  Lt
  // >
  Gt
  // =
  Eq
  // concurrent
  Cc
}

pub type VTime =
  icounter.ICounter

pub fn new() -> VTime {
  icounter.new()
}

pub fn inc(a: VTime, id: replica.ReplicaId) -> VTime {
  icounter.inc(a, id)
}

pub fn merge(a: VTime, b: VTime) -> VTime {
  icounter.merge(a, b)
}

pub fn compare(a: VTime, b: VTime) -> VOrd {
  let val_or_default = fn(map: VTime, key: replica.ReplicaId) {
    case dict.get(map, key) {
      Ok(v) -> v
      _ -> 0
    }
  }

  [dict.keys(a), dict.keys(b)]
  |> list.flatten
  |> list.unique
  |> list.fold(Eq, fn(prev, k) {
    let va = val_or_default(a, k)
    let vb = val_or_default(b, k)
    let o = int.compare(va, vb)
    case prev, o {
      Eq, order.Gt -> Gt
      Eq, order.Lt -> Lt
      Lt, order.Gt -> Cc
      Gt, order.Lt -> Cc
      _, _ -> prev
    }
  })
}

/// Returns the replica with the largest VTime count
pub fn max(a: VTime) {
  let #(max_key, _) =
    a
    |> dict.fold(#(option.None, option.None), fn(acc, key, value) {
      case acc {
        #(Some(prev_key), Some(prev_value)) -> {
          case int.compare(prev_value, value) {
            order.Gt -> #(Some(prev_key), Some(prev_value))
            _ -> #(Some(key), Some(value))
          }
        }
        _ -> #(Some(key), Some(value))
      }
    })
  max_key
}
