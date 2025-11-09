import gcrdt/dot
import gleam/list
import gleam/string
import gleeunit/should

// Basic DotKernel operations

pub fn new_kernel_is_empty_test() {
  dot.new()
  |> dot.values
  |> should.equal([])
}

pub fn add_single_value_test() {
  let replica_id = "a"

  let #(kernel, _delta) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  kernel
  |> dot.values
  |> should.equal(["apple"])
}

pub fn add_multiple_values_test() {
  let replica_id = "a"

  let #(kernel, delta) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, delta) =
    kernel
    |> dot.add(delta, "banana", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(delta, "cherry", replica_id)

  let values = kernel |> dot.values |> list.sort(by: string.compare)
  values |> should.equal(["apple", "banana", "cherry"])
}

pub fn add_same_value_multiple_times_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(dot.new(), "apple", replica_id)

  // Should have 3 entries with different dots
  kernel
  |> dot.values
  |> list.length
  |> should.equal(3)
}

pub fn remove_existing_value_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(dot.new(), "banana", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.remove(dot.new(), "apple")

  let values = kernel |> dot.values
  values |> should.equal(["banana"])
}

pub fn remove_all_instances_of_value_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.add(dot.new(), "banana", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.remove(dot.new(), "apple")

  let values = kernel |> dot.values
  values |> should.equal(["banana"])
}

pub fn remove_non_existing_value_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.remove(dot.new(), "banana")

  kernel
  |> dot.values
  |> should.equal(["apple"])
}

// Merge operations

pub fn merge_empty_kernels_test() {
  let merged = dot.merge(dot.new(), dot.new())

  merged
  |> dot.values
  |> should.equal([])
}

pub fn merge_with_empty_kernel_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let merged = dot.merge(kernel, dot.new())

  merged
  |> dot.values
  |> should.equal(["apple"])
}

pub fn merge_disjoint_kernels_test() {
  let r1 = "a"
  let r2 = "b"

  let #(kernel1, delta1) =
    dot.new()
    |> dot.add(dot.new(), "apple", r1)

  let #(kernel1, _) =
    kernel1
    |> dot.add(delta1, "banana", r1)

  let #(kernel2, delta2) =
    dot.new()
    |> dot.add(dot.new(), "cherry", r2)

  let #(kernel2, _) =
    kernel2
    |> dot.add(delta2, "date", r2)

  let merged = dot.merge(kernel1, kernel2)
  let values = merged |> dot.values |> list.sort(string.compare)

  values |> should.equal(["apple", "banana", "cherry", "date"])
}

pub fn merge_is_commutative_test() {
  let r1 = "a"
  let r2 = "b"

  let #(kernel1, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", r1)

  let #(kernel2, _) =
    dot.new()
    |> dot.add(dot.new(), "banana", r2)

  let merge1 = dot.merge(kernel1, kernel2) |> dot.values
  let merge2 = dot.merge(kernel2, kernel1) |> dot.values

  merge1 |> should.equal(merge2)
}

pub fn merge_is_idempotent_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let merged1 = dot.merge(kernel, kernel)
  let merged2 = dot.merge(merged1, kernel)

  merged1 |> dot.values |> should.equal(merged2 |> dot.values)
}

pub fn merge_is_associative_test() {
  let r1 = "a"
  let r2 = "b"
  let r3 = "c"

  let #(k1, _) = dot.new() |> dot.add(dot.new(), "a", r1)
  let #(k2, _) = dot.new() |> dot.add(dot.new(), "b", r2)
  let #(k3, _) = dot.new() |> dot.add(dot.new(), "c", r3)

  let merge1 = dot.merge(dot.merge(k1, k2), k3) |> dot.values
  let merge2 = dot.merge(k1, dot.merge(k2, k3)) |> dot.values

  merge1 |> should.equal(merge2)
}

// Delta propagation tests

pub fn delta_contains_added_value_test() {
  let replica_id = "a"

  let #(_kernel, delta) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  delta
  |> dot.values
  |> should.equal(["apple"])
}

pub fn delta_accumulates_operations_test() {
  let replica_id = "a"

  let #(kernel, delta) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(_kernel, delta) =
    kernel
    |> dot.add(delta, "banana", replica_id)

  let values = delta |> dot.values |> list.sort(string.compare)
  values |> should.equal(["apple", "banana"])
}

pub fn remove_updates_delta_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(_kernel, delta) =
    kernel
    |> dot.remove(dot.new(), "apple")

  // Delta should be non-empty (contains context info about removal)
  // but shouldn't contain the value
  delta
  |> dot.values
  |> should.equal([])
}

// Multi-replica scenarios

pub fn concurrent_adds_different_replicas_test() {
  let r1 = "a"
  let r2 = "b"

  let #(k1, _) = dot.new() |> dot.add(dot.new(), "apple", r1)
  let #(k2, _) = dot.new() |> dot.add(dot.new(), "banana", r2)

  let merged = dot.merge(k1, k2)
  let values = merged |> dot.values |> list.sort(string.compare)

  values |> should.equal(["apple", "banana"])
}

pub fn concurrent_adds_same_value_different_replicas_test() {
  let r1 = "a"
  let r2 = "b"

  let #(k1, _) = dot.new() |> dot.add(dot.new(), "apple", r1)
  let #(k2, _) = dot.new() |> dot.add(dot.new(), "apple", r2)

  let merged = dot.merge(k1, k2)

  // Should have both instances (different dots)
  merged
  |> dot.values
  |> list.length
  |> should.equal(2)
}

pub fn add_remove_sequence_test() {
  let replica_id = "a"

  let #(k1, _) = dot.new() |> dot.add(dot.new(), "apple", replica_id)
  let #(k2, _) = k1 |> dot.remove(dot.new(), "apple")
  let #(k3, _) = k2 |> dot.add(dot.new(), "apple", replica_id)

  k3
  |> dot.values
  |> should.equal(["apple"])
}

pub fn concurrent_add_and_remove_test() {
  let r1 = "a"

  let #(kernel, delta) = #(dot.new(), dot.new())

  // Replica 1 adds
  let #(k1, _) = kernel |> dot.add(delta, "apple", r1)

  // Replica 2 removes (but doesn't know about the add)
  let #(k2, _) = dot.new() |> dot.remove(dot.new(), "apple")

  // Merge should preserve the add (add-wins semantics)
  let merged = dot.merge(k1, k2)

  merged
  |> dot.values
  |> should.equal(["apple"])
}

pub fn out_of_order_delivery_converges_test() {
  let r1 = "a"

  let #(kernel, delta) = #(dot.new(), dot.new())

  // R1: add apple
  let #(k1, d1) = kernel |> dot.add(delta, "apple", r1)

  // R1: add banana
  let #(k1, d2) = k1 |> dot.add(d1, "banana", r1)

  // R2 receives deltas out of order
  let k2 =
    dot.new()
    |> dot.merge(d2)
    // banana first
    |> dot.merge(d1)
  // apple second

  // Should still converge to same result
  let v1 = k1 |> dot.values
  let v2 = k2 |> dot.values

  list.length(v1) |> should.equal(list.length(v2))
}

pub fn multiple_removes_same_value_test() {
  let replica_id = "a"

  let #(kernel, _) =
    dot.new()
    |> dot.add(dot.new(), "apple", replica_id)

  let #(kernel, _) =
    kernel
    |> dot.remove(dot.new(), "apple")

  // Remove again (should be no-op)
  let #(kernel, _) =
    kernel
    |> dot.remove(dot.new(), "apple")

  kernel
  |> dot.values
  |> should.equal([])
}

pub fn complex_merge_scenario_test() {
  let r1 = "a"
  let r2 = "b"
  let r3 = "c"

  // R1: add apple, banana
  let #(k1, d1) = dot.new() |> dot.add(dot.new(), "apple", r1)
  let #(k1, d1) = k1 |> dot.add(d1, "banana", r1)

  // R2: add cherry, remove apple (concurrent with R1)
  let #(k2, d2) = k1 |> dot.add(d1, "cherry", r2)
  let #(k2, d2) = k2 |> dot.remove(d2, "apple")

  // R3: add date
  let #(k3, _) = k2 |> dot.add(d2, "date", r3)

  // Merge all
  let merged = dot.merge(dot.merge(k1, k2), k3)
  let values = merged |> dot.values

  values
  |> list.sort(string.compare)
  |> should.equal(["banana", "cherry", "date"])
}

pub fn sequential_operations_same_replica_test() {
  let replica_id = "a"

  let kernel = dot.new()
  let delta = dot.new()

  let #(kernel, delta) = kernel |> dot.add(delta, "a", replica_id)
  let #(kernel, delta) = kernel |> dot.add(delta, "b", replica_id)
  let #(kernel, delta) = kernel |> dot.remove(delta, "a")
  let #(kernel, delta) = kernel |> dot.add(delta, "c", replica_id)
  let #(kernel, _) = kernel |> dot.remove(delta, "b")

  let values = kernel |> dot.values
  values |> should.equal(["c"])
}
