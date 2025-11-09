import gcrdt/awor
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

// Basic operations tests

pub fn new_awor_is_empty_test() {
  awor.new()
  |> awor.value
  |> should.equal([])
}

pub fn add_single_element_test() {
  let replica_id = "a"

  awor.new()
  |> awor.add("apple", replica_id)
  |> awor.value
  |> should.equal(["apple"])
}

pub fn add_multiple_elements_test() {
  let replica_id = "a"

  awor.new()
  |> awor.add("apple", replica_id)
  |> awor.add("banana", replica_id)
  |> awor.add("cherry", replica_id)
  |> awor.value
  |> list.sort(string.compare)
  |> should.equal(["apple", "banana", "cherry"])
}

pub fn remove_existing_element_test() {
  let replica_id = "a"

  let result =
    awor.new()
    |> awor.add("apple", replica_id)
    |> awor.add("banana", replica_id)
    |> awor.remove("apple")
    |> awor.value

  result |> should.equal(["banana"])
}

pub fn remove_non_existing_element_test() {
  let replica_id = "a"

  awor.new()
  |> awor.add("apple", replica_id)
  |> awor.remove("banana")
  |> awor.value
  |> should.equal(["apple"])
}

pub fn remove_from_empty_set_test() {
  awor.new()
  |> awor.remove("apple")
  |> awor.value
  |> should.equal([])
}

// Add-wins semantics tests

pub fn concurrent_add_and_remove_add_wins_test() {
  let replica1 = "a"

  // Simulate concurrent operations
  let set1 =
    awor.new()
    |> awor.add("item", replica1)

  let set2 =
    awor.new()
    |> awor.remove("item")

  // Merge both ways should give same result
  let merged1 = awor.merge(set1, set2)
  let merged2 = awor.merge(set2, set1)

  // Add should win
  merged1 |> awor.value |> should.equal(["item"])
  merged2 |> awor.value |> should.equal(["item"])
}

pub fn re_add_after_remove_test() {
  let replica_id = "a"

  awor.new()
  |> awor.add("apple", replica_id)
  |> awor.remove("apple")
  |> awor.add("apple", replica_id)
  |> awor.value
  |> should.equal(["apple"])
}

// Merge tests

pub fn merge_disjoint_sets_test() {
  let replica1 = "a"
  let replica2 = "b"

  let set1 =
    awor.new()
    |> awor.add("apple", replica1)
    |> awor.add("banana", replica1)

  let set2 =
    awor.new()
    |> awor.add("cherry", replica2)
    |> awor.add("date", replica2)

  let result = awor.merge(set1, set2) |> awor.value |> list.sort(string.compare)

  result |> should.equal(["apple", "banana", "cherry", "date"])
}

pub fn merge_overlapping_sets_test() {
  let replica1 = "a"
  let replica2 = "b"

  let set1 =
    awor.new()
    |> awor.add("apple", replica1)
    |> awor.add("banana", replica1)

  let set2 =
    set1
    |> awor.add("banana", replica2)
    |> awor.add("cherry", replica2)

  let result = awor.merge(set1, set2) |> awor.value |> list.sort(string.compare)

  result |> should.equal(["apple", "banana", "cherry"])
}

pub fn merge_is_commutative_test() {
  let replica1 = "a"
  let replica2 = "b"

  let set1 =
    awor.new()
    |> awor.add("apple", replica1)
    |> awor.remove("banana")

  let set2 =
    awor.new()
    |> awor.add("banana", replica2)
    |> awor.add("cherry", replica2)

  let merge1 = awor.merge(set1, set2) |> awor.value
  let merge2 = awor.merge(set2, set1) |> awor.value

  // Both merges should produce the same result
  merge1 |> should.equal(merge2)
}

pub fn merge_is_idempotent_test() {
  let replica_id = "a"

  let set1 =
    awor.new()
    |> awor.add("apple", replica_id)
    |> awor.add("banana", replica_id)

  let merged_once = awor.merge(set1, set1)
  let merged_twice = awor.merge(merged_once, set1)

  merged_once |> awor.value |> should.equal(merged_twice |> awor.value)
}

// Delta merge tests

pub fn merge_delta_with_empty_set_test() {
  let replica_id = "a"

  let set_with_delta =
    awor.new()
    |> awor.add("apple", replica_id)

  case set_with_delta.delta {
    Some(delta) -> {
      awor.new()
      |> awor.merge_delta(delta)
      |> awor.value
      |> should.equal(["apple"])
    }
    None -> should.fail()
  }
}

pub fn delta_propagation_test() {
  let replica1 = "a"
  let replica2 = "b"

  // Replica 1 adds an item
  let set1 =
    awor.new()
    |> awor.add("apple", replica1)

  // Extract delta and apply to replica 2
  case set1.delta {
    Some(delta) -> {
      let set2 =
        awor.new()
        |> awor.merge_delta(delta)

      // Replica 2 adds another item
      let set2 = set2 |> awor.add("banana", replica2)

      // Both replicas should eventually converge
      let final_set =
        awor.merge(set1, set2) |> awor.value |> list.sort(string.compare)

      final_set |> should.equal(["apple", "banana"])
    }
    None -> should.fail()
  }
}

// Multi-replica scenarios

pub fn three_way_merge_test() {
  let r1 = "a"
  let r2 = "b"
  let r3 = "c"

  let set1 = awor.new() |> awor.add("a", r1)
  let set2 = awor.new() |> awor.add("b", r2)
  let set3 = awor.new() |> awor.add("c", r3)

  let merged =
    awor.merge(awor.merge(set1, set2), set3)
    |> awor.value
    |> list.sort(string.compare)

  merged |> should.equal(["a", "b", "c"])
}

pub fn concurrent_add_same_element_test() {
  let replica1 = "a"
  let replica2 = "b"

  let set1 = awor.new() |> awor.add("apple", replica1)
  let set2 = set1 |> awor.add("apple", replica2)

  awor.merge(set1, set2)
  |> awor.value
  |> list.sort(string.compare)
  |> should.equal(["apple"])
}

pub fn remove_add_remove_sequence_test() {
  let replica_id = "a"

  awor.new()
  |> awor.add("item", replica_id)
  |> awor.remove("item")
  |> awor.add("item", replica_id)
  |> awor.remove("item")
  |> awor.value
  |> should.equal([])
}
