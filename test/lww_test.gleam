import gcrdt/lww
import gleeunit/should

pub fn new_creates_empty_register_test() {
  let reg = lww.new()
  lww.value(reg)
  |> should.equal(Error(Nil))
}

pub fn set_updates_value_test() {
  let reg = lww.new()
  let reg1 = lww.set(reg, "hello", "a")

  lww.value(reg1)
  |> should.equal(Ok("hello"))
}

pub fn set_multiple_times_same_replica_test() {
  let reg = lww.new()
  let reg1 = reg |> lww.set("first", "a")
  let reg2 = reg1 |> lww.set("second", "a")
  let reg3 = reg2 |> lww.set("third", "a")

  lww.value(reg3)
  |> should.equal(Ok("third"))
}

pub fn set_different_replicas_test() {
  let reg = lww.new()
  let reg1 = lww.set(reg, "replica1", "a")
  let reg2 = lww.set(reg, "replica2", "b")

  lww.value(reg1)
  |> should.equal(Ok("replica1"))

  lww.value(reg2)
  |> should.equal(Ok("replica2"))
}

// Value retrieval tests
pub fn value_returns_error_for_empty_test() {
  let reg = lww.new()
  lww.value(reg)
  |> should.be_error()
}

pub fn value_returns_latest_write_test() {
  let reg =
    lww.new()
    |> lww.set("v1", "a")
    |> lww.set("v2", "a")
    |> lww.set("v3", "a")

  lww.value(reg)
  |> should.equal(Ok("v3"))
}

pub fn value_with_int_type_test() {
  let reg =
    lww.new()
    |> lww.set(42, "a")
    |> lww.set(100, "a")

  lww.value(reg)
  |> should.equal(Ok(100))
}

pub fn value_with_list_type_test() {
  let reg =
    lww.new()
    |> lww.set([1, 2, 3], "a")

  lww.value(reg)
  |> should.equal(Ok([1, 2, 3]))
}

// Merge tests - sequential updates
pub fn merge_empty_registers_test() {
  let reg1 = lww.new()
  let reg2 = lww.new()
  let merged = lww.merge(reg1, reg2)

  lww.value(merged)
  |> should.equal(Error(Nil))
}

pub fn merge_empty_with_non_empty_test() {
  let reg1 = lww.new()
  let reg2 = lww.new() |> lww.set("value", "a")

  let merged = lww.merge(reg1, reg2)
  lww.value(merged)
  |> should.equal(Ok("value"))
}

pub fn merge_sequential_writes_test() {
  let reg1 = lww.new() |> lww.set("first", "a")
  let reg2 = reg1 |> lww.set("second", "a")

  let merged = lww.merge(reg1, reg2)
  lww.value(merged)
  |> should.equal(Ok("second"))
}

pub fn merge_favors_greater_timestamp_test() {
  let reg1 = lww.new() |> lww.set("old", "a")
  let reg2 = reg1 |> lww.set("new", "a")

  // reg2 has greater timestamp
  let merged = lww.merge(reg1, reg2)
  lww.value(merged)
  |> should.equal(Ok("new"))

  // Order shouldn't matter
  let merged2 = lww.merge(reg2, reg1)
  lww.value(merged2)
  |> should.equal(Ok("new"))
}

// Merge tests - concurrent updates
pub fn merge_concurrent_writes_test() {
  let base = lww.new()
  let reg1 = lww.set(base, "replica1", "a")
  let reg2 = lww.set(reg1, "replica2", "b")

  // These are concurrent, merge should pick one consistently
  let merged1 = lww.merge(reg1, reg2)
  let merged2 = lww.merge(reg2, reg1)

  // The merge should be deterministic based on replica ID
  lww.value(merged1)
  |> should.equal(lww.value(merged2))
}

pub fn merge_concurrent_picks_higher_id_test() {
  let base = lww.new()
  let reg1 = lww.set(base, "replica1", "a")
  let reg2 = lww.set(base, "replica2", "b")
  let reg3 = lww.set(base, "replica3", "c")

  let merged12 = lww.merge(reg1, reg2)
  lww.value(merged12)
  |> should.equal(Ok("replica2"))

  let merged23 = lww.merge(reg2, reg3)
  lww.value(merged23)
  |> should.equal(Ok("replica3"))

  let merged13 = lww.merge(reg1, reg3)
  lww.value(merged13)
  |> should.equal(Ok("replica3"))
}

pub fn merge_complex_concurrent_test() {
  let base = lww.new()

  // Multiple writes on different replicas
  let reg1 = base |> lww.set("r1v1", "a") |> lww.set("r1v2", "a")
  let reg2 = base |> lww.set("r2v1", "b") |> lww.set("r2v2", "b")

  let merged = lww.merge(reg1, reg2)

  // Both have 2 increments, so it's concurrent - higher ID wins
  lww.value(merged)
  |> should.equal(Ok("r2v2"))
}

// Merge properties tests
pub fn merge_is_idempotent_test() {
  let reg = lww.new() |> lww.set("value", "a")
  let merged = lww.merge(reg, reg)

  lww.value(merged)
  |> should.equal(lww.value(reg))
}

pub fn merge_with_self_after_update_test() {
  let reg1 = lww.new() |> lww.set("first", "a")
  let reg2 = reg1 |> lww.set("second", "a")

  let merged = lww.merge(reg1, reg2)
  lww.value(merged)
  |> should.equal(Ok("second"))

  let merged_reverse = lww.merge(reg2, reg1)
  lww.value(merged_reverse)
  |> should.equal(Ok("second"))
}

// Integration tests
pub fn distributed_scenario_test() {
  // Initial state
  let initial = lww.new()

  // Replica 1 writes
  let r1 = initial |> lww.set("r1_write1", "a")

  // Replica 2 writes concurrently
  let r2 = r1 |> lww.set("r2_write1", "b")

  // Replicas sync
  let synced1 = lww.merge(r1, r2)
  let synced2 = lww.merge(r2, r1)

  // Both should have same value after sync
  lww.value(synced1)
  |> should.equal(lww.value(synced2))

  // Replica 1 writes again after sync
  let r1_after = lww.set(synced1, "r1_write2", "a")

  // This should override the previous merge
  lww.value(r1_after)
  |> should.equal(Ok("r1_write2"))
}

pub fn three_way_merge_test() {
  let base = lww.new()

  let r1 = base |> lww.set("replica1", "a")
  let r2 = r1 |> lww.set("replica2", "b")
  let r3 = r2 |> lww.set("replica3", "c")

  // Merge in different orders
  let m1 = lww.merge(lww.merge(r1, r2), r3)
  let m2 = lww.merge(r1, lww.merge(r2, r3))
  let m3 = lww.merge(lww.merge(r1, r3), r2)

  // All should converge to same value
  let v1 = lww.value(m1)
  let v2 = lww.value(m2)
  let v3 = lww.value(m3)

  v1 |> should.equal(v2)
  v2 |> should.equal(v3)
}

pub fn causally_ordered_updates_test() {
  let r0 = lww.new()

  // Replica 1 makes first write
  let r1_v1 = r0 |> lww.set("v1", "a")

  // Replica 2 receives r1_v1 and updates
  let r2_v2 = r1_v1 |> lww.set("v2", "b")

  // Replica 3 receives r2_v2 and updates
  let r3_v3 = r2_v2 |> lww.set("v3", "c")

  // Latest write should win
  lww.value(r3_v3)
  |> should.equal(Ok("v3"))

  // Merging with earlier versions should keep latest
  let merged = lww.merge(r3_v3, r1_v1)
  lww.value(merged)
  |> should.equal(Ok("v3"))
}

pub fn concurrent_then_sequential_test() {
  let base = lww.new()

  // Concurrent writes
  let r1 = base |> lww.set("concurrent1", "a")
  let r2 = r1 |> lww.set("concurrent2", "b")

  // Merge concurrent writes
  let merged = lww.merge(r1, r2)

  // Sequential write after merge
  let r3 = merged |> lww.set("sequential", "c")

  // Sequential write should win
  lww.value(r3)
  |> should.equal(Ok("sequential"))

  // Even when merged with old concurrent versions
  let final_merge = lww.merge(lww.merge(r3, r1), r2)
  lww.value(final_merge)
  |> should.equal(Ok("sequential"))
}

pub fn multi_replica_convergence_test() {
  // Simulate 4 replicas all writing concurrently
  let base = lww.new()

  let r1 = base |> lww.set("replica1", "a")
  let r2 = base |> lww.set("replica2", "b")
  let r3 = base |> lww.set("replica3", "c")
  let r4 = base |> lww.set("replica4", "d")

  // Merge in a tree pattern
  let m12 = lww.merge(r1, r2)
  let m34 = lww.merge(r3, r4)
  let final = lww.merge(m12, m34)

  // Should pick highest replica ID
  lww.value(final)
  |> should.equal(Ok("replica4"))
}

type User {
  User(name: String, age: Int)
}

pub fn type_safety_test() {
  // Test with different types

  let user_reg =
    lww.new()
    |> lww.set(User("Alice", 30), "a")
    |> lww.set(User("Bob", 25), "a")

  lww.value(user_reg)
  |> should.equal(Ok(User("Bob", 25)))
}
