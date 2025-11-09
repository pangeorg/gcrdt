import gcrdt/replica
import gleam/dict
import gleam/int
import gleam/option

/// Continously increasing counter
/// Maps Replica to count
pub type ICounter =
  dict.Dict(replica.ReplicaId, Int)

pub fn new() -> ICounter {
  dict.new()
}

pub fn value(counter: ICounter) -> Int {
  counter |> dict.fold(0, fn(acc, _k, v) { acc + v })
}

pub fn inc(counter: ICounter, id: replica.ReplicaId) {
  let increment = fn(x) {
    case x {
      option.Some(i) -> i + 1
      _ -> 1
    }
  }
  counter |> dict.upsert(id, increment)
}

pub fn merge(a: ICounter, b: ICounter) -> ICounter {
  a
  |> dict.fold(b, fn(acc, ka, va) {
    case dict.get(acc, ka) {
      Ok(vb) -> dict.insert(acc, ka, int.max(va, vb))
      _ -> dict.insert(acc, ka, va)
    }
  })
}

pub fn merge_all(counters: List(ICounter)) {
  case counters {
    [a] -> a
    [a, b] -> merge(a, b)
    [a, b, ..rest] -> {
      let merged = merge(a, b)
      merge_all([merged, ..rest])
    }
    _ -> new()
  }
}
