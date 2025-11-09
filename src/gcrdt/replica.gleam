import gleam/string

// FIXME: Make this generic or use guid's or something
pub type ReplicaId =
  String

pub fn compare(a: ReplicaId, b: ReplicaId) {
  string.compare(a, b)
}
