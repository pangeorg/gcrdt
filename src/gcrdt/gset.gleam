import gleam/set

// Growing only set
pub type GSet(a) =
  set.Set(a)

pub fn new() {
  set.new()
}

pub fn add(gset: GSet(a), value: a) {
  gset |> set.insert(value)
}

pub fn contains(gset: GSet(a), value: a) {
  gset |> set.contains(value)
}

pub fn merge(a: GSet(a), b: GSet(a)) {
  set.union(a, b)
}
