import gcrdt/vtime
import gleam/option
import gleeunit/should

// Basic operations tests
pub fn new_creates_empty_vtime_test() {
  let v = vtime.new()
  vtime.compare(v, v)
  |> should.equal(vtime.Eq)
}

pub fn inc_increments_counter_test() {
  let v = vtime.new()
  let v1 = vtime.inc(v, 1)
  let v2 = vtime.inc(v1, 1)

  vtime.compare(v, v1)
  |> should.equal(vtime.Lt)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Lt)
}

pub fn inc_multiple_replicas_test() {
  let v = vtime.new()
  let v1 = vtime.inc(v, 1)
  let v2 = vtime.inc(v, 2)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Cc)
}

// Comparison tests
pub fn compare_equal_vtimes_test() {
  let v1 = vtime.new()
  let v2 = vtime.new()

  vtime.compare(v1, v2)
  |> should.equal(vtime.Eq)
}

pub fn compare_greater_than_test() {
  let v1 = vtime.new()
  let v2 = vtime.inc(v1, 1)

  vtime.compare(v2, v1)
  |> should.equal(vtime.Gt)
}

pub fn compare_less_than_test() {
  let v1 = vtime.new()
  let v2 = vtime.inc(v1, 1)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Lt)
}

pub fn compare_concurrent_test() {
  let v = vtime.new()
  let v1 = vtime.inc(v, 1)
  let v2 = vtime.inc(v, 2)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Cc)

  vtime.compare(v2, v1)
  |> should.equal(vtime.Cc)
}

pub fn compare_concurrent_complex_test() {
  let v = vtime.new()
  let v1 = v |> vtime.inc(1) |> vtime.inc(1)
  let v2 = v |> vtime.inc(2) |> vtime.inc(2) |> vtime.inc(2)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Cc)
}

pub fn compare_partial_order_test() {
  let v = vtime.new()
  let v1 = v |> vtime.inc(1) |> vtime.inc(2)
  let v2 = v |> vtime.inc(1)

  vtime.compare(v1, v2)
  |> should.equal(vtime.Gt)

  vtime.compare(v2, v1)
  |> should.equal(vtime.Lt)
}

// Merge tests
pub fn merge_empty_vtimes_test() {
  let v1 = vtime.new()
  let v2 = vtime.new()
  let merged = vtime.merge(v1, v2)

  vtime.compare(merged, v1)
  |> should.equal(vtime.Eq)
}

pub fn merge_with_empty_test() {
  let v1 = vtime.new() |> vtime.inc(1)
  let v2 = vtime.new()
  let merged = vtime.merge(v1, v2)

  vtime.compare(merged, v1)
  |> should.equal(vtime.Eq)
}

pub fn merge_disjoint_vtimes_test() {
  let v1 = vtime.new() |> vtime.inc(1)
  let v2 = vtime.new() |> vtime.inc(2)
  let merged = vtime.merge(v1, v2)

  vtime.compare(merged, v1)
  |> should.equal(vtime.Gt)

  vtime.compare(merged, v2)
  |> should.equal(vtime.Gt)
}

pub fn merge_overlapping_vtimes_test() {
  let v = vtime.new()
  let v1 = v |> vtime.inc(1) |> vtime.inc(1)
  let v2 = v |> vtime.inc(1) |> vtime.inc(2)
  let merged = vtime.merge(v1, v2)

  vtime.compare(merged, v1)
  |> should.equal(vtime.Gt)

  vtime.compare(merged, v2)
  |> should.equal(vtime.Gt)
}

pub fn merge_is_commutative_test() {
  let v1 = vtime.new() |> vtime.inc(1) |> vtime.inc(1)
  let v2 = vtime.new() |> vtime.inc(2)

  let m1 = vtime.merge(v1, v2)
  let m2 = vtime.merge(v2, v1)

  vtime.compare(m1, m2)
  |> should.equal(vtime.Eq)
}

pub fn merge_is_associative_test() {
  let v1 = vtime.new() |> vtime.inc(1)
  let v2 = vtime.new() |> vtime.inc(2)
  let v3 = vtime.new() |> vtime.inc(3)

  let m1 = vtime.merge(vtime.merge(v1, v2), v3)
  let m2 = vtime.merge(v1, vtime.merge(v2, v3))

  vtime.compare(m1, m2)
  |> should.equal(vtime.Eq)
}

pub fn merge_is_idempotent_test() {
  let v1 = vtime.new() |> vtime.inc(1) |> vtime.inc(2)
  let merged = vtime.merge(v1, v1)

  vtime.compare(merged, v1)
  |> should.equal(vtime.Eq)
}

// Max tests
pub fn max_empty_vtime_test() {
  let v = vtime.new()
  vtime.max(v)
  |> should.equal(option.None)
}

pub fn max_single_replica_test() {
  let v = vtime.new() |> vtime.inc(5)
  vtime.max(v)
  |> should.equal(option.Some(5))
}

pub fn max_multiple_replicas_test() {
  let v =
    vtime.new()
    |> vtime.inc(1)
    |> vtime.inc(3)
    |> vtime.inc(2)

  vtime.max(v)
  |> should.equal(option.Some(3))
}

pub fn max_returns_largest_id_test() {
  let v =
    vtime.new()
    |> vtime.inc(10)
    |> vtime.inc(100)
    |> vtime.inc(100)
    |> vtime.inc(5)

  vtime.max(v)
  |> should.equal(option.Some(100))
}

// Integration tests
pub fn causality_tracking_test() {
  // Simulate a distributed system scenario
  let v0 = vtime.new()

  // Replica 1 makes changes
  let v1 = v0 |> vtime.inc(1) |> vtime.inc(1)

  // Replica 2 makes changes independently
  let v2 = v0 |> vtime.inc(2)

  // These should be concurrent
  vtime.compare(v1, v2)
  |> should.equal(vtime.Cc)

  // Replica 3 receives v1 and makes changes
  let v3 = v1 |> vtime.inc(3)

  // v3 should be greater than v1
  vtime.compare(v3, v1)
  |> should.equal(vtime.Gt)

  // v3 should be concurrent with v2
  vtime.compare(v3, v2)
  |> should.equal(vtime.Cc)

  // Merge all versions
  let final = vtime.merge(v3, v2)

  // Final should dominate all
  vtime.compare(final, v1)
  |> should.equal(vtime.Gt)

  vtime.compare(final, v2)
  |> should.equal(vtime.Gt)

  vtime.compare(final, v3)
  |> should.equal(vtime.Gt)
}

pub fn transitivity_test() {
  let v1 = vtime.new() |> vtime.inc(1)
  let v2 = v1 |> vtime.inc(1)
  let v3 = v2 |> vtime.inc(1)

  // If v1 < v2 and v2 < v3, then v1 < v3
  vtime.compare(v1, v2)
  |> should.equal(vtime.Lt)

  vtime.compare(v2, v3)
  |> should.equal(vtime.Lt)

  vtime.compare(v1, v3)
  |> should.equal(vtime.Lt)
}
