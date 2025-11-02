import gcrdt/icounter

/// increasing/decreasing counter
pub opaque type IDCounter {
  IDCounter(i: icounter.ICounter, d: icounter.ICounter)
}

pub fn new() -> IDCounter {
  IDCounter(i: icounter.new(), d: icounter.new())
}

pub fn value(counter: IDCounter) -> Int {
  icounter.value(counter.i) - icounter.value(counter.d)
}

pub fn inc(counter: IDCounter, id: Int) {
  let i = icounter.inc(counter.i, id)
  IDCounter(i: i, d: counter.d)
}

pub fn dec(counter: IDCounter, id: Int) {
  let d = icounter.inc(counter.d, id)
  IDCounter(i: counter.i, d: d)
}

pub fn merge(a: IDCounter, b: IDCounter) {
  let i = icounter.merge(a.i, b.i)
  let d = icounter.merge(a.d, b.d)
  IDCounter(i:, d:)
}

pub fn merge_all(counters: List(IDCounter)) {
  case counters {
    [a] -> a
    [a, b] -> merge(a, b)
    [a, b, ..rest] -> {
      let merged = merge(a, b)
      merge_all([merged, ..rest])
    }
    [] -> new()
  }
}
