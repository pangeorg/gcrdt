import gcrdt/gset

// Growing only set
pub type PSet(a) {
  Pset(growing: gset.GSet(a), tombstone: gset.GSet(a))
}

pub fn new() {
  Pset(growing: gset.new(), tombstone: gset.new())
}

pub fn add(pset: PSet(a), value: a) {
  let growing = pset.growing |> gset.add(value)
  Pset(growing: growing, tombstone: pset.tombstone)
}

pub fn remove(pset: PSet(a), value: a) {
  let tombstone = pset.tombstone |> gset.add(value)
  Pset(growing: pset.growing, tombstone: tombstone)
}

pub fn contains(pset: PSet(a), value: a) {
  pset.growing |> gset.contains(value)
}

pub fn merge(a: PSet(a), b: PSet(a)) {
  let growing = gset.merge(a.growing, b.growing)
  let tombstone = gset.merge(a.tombstone, b.tombstone)
  Pset(growing:, tombstone:)
}
