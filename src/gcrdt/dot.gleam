import gcrdt/replica.{type ReplicaId}
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set

pub opaque type DotKernel(a) {
  DotKernel(ctx: DotContext, entries: dict.Dict(Dot, a))
}

pub fn new() {
  DotKernel(ctx: new_ctx(), entries: dict.new())
}

pub fn values(kernel: DotKernel(a)) {
  kernel.entries |> dict.values
}

pub fn merge(a: DotKernel(a), b: DotKernel(a)) {
  let active =
    b.entries
    |> dict.fold(a.entries, fn(acc, dot, vb) {
      case a.entries |> dict.has_key(dot) || a.ctx |> ctx_contains(dot) {
        False -> acc |> dict.insert(dot, vb)
        _ -> acc
      }
    })

  let entries =
    a.entries
    |> dict.fold(active, fn(acc, dot, _) {
      // remove elements visible in dot context but not among entries
      case
        b.ctx |> ctx_contains(dot)
        && bool.negate(b.entries |> dict.has_key(dot))
      {
        True -> acc |> dict.drop([dot])
        _ -> acc
      }
    })

  let ctx = ctx_merge(a.ctx, b.ctx)

  DotKernel(ctx:, entries:)
}

pub fn add(kernel: DotKernel(a), delta: DotKernel(a), value: a, id: Int) {
  let #(dot, ctx) = ctx_next(kernel.ctx, id)
  let kernel =
    DotKernel(ctx: ctx, entries: kernel.entries |> dict.insert(dot, value))
  let delta =
    DotKernel(
      ctx: delta.ctx |> ctx_add(dot),
      entries: delta.entries |> dict.insert(dot, value),
    )
  #(kernel, delta)
}

pub fn remove(kernel: DotKernel(a), delta: DotKernel(a), value: a) {
  let #(entries, delta_ctx) =
    kernel.entries
    |> dict.fold(#(kernel.entries, delta.ctx), fn(acc, dot, v) {
      let #(k_entries, delta_ctx) = acc
      case value == v {
        True -> #(k_entries |> dict.drop([dot]), delta_ctx |> ctx_add(dot))
        _ -> acc
      }
    })
  let kernel = DotKernel(ctx: kernel.ctx, entries:)
  let delta = DotKernel(ctx: delta_ctx |> ctx_compact(), entries: delta.entries)
  #(kernel, delta)
}

/// A `Dot` represents a event count for a replica id
type Dot =
  #(ReplicaId, Int)

/// A `VectorClock` keeps track of the most recent Event per replica
type VectorClock =
  dict.Dict(ReplicaId, Int)

// logical representation of all observed events from a perspective of given replica 
type DotContext {
  DotContext(clock: VectorClock, cloud: set.Set(Dot))
}

fn new_ctx() {
  DotContext(dict.new(), set.new())
}

fn ctx_contains(ctx: DotContext, dot: Dot) {
  let #(id, num) = dot
  case ctx.clock |> dict.get(id) {
    Ok(vc) -> {
      case vc >= num {
        True -> True
        _ -> ctx.cloud |> set.contains(dot)
      }
    }
    _ -> ctx.cloud |> set.contains(dot)
  }
}

fn ctx_add(ctx: DotContext, dot: Dot) {
  // TODO: Add fast path without compact?
  DotContext(cloud: ctx.cloud |> set.insert(dot), clock: ctx.clock)
  |> ctx_compact()
}

/// Create a new `Dot` for the given context and id
/// Returns the newly generated dot (representing the most recent event for this replica)
/// and the updated DotContext
fn ctx_next(ctx: DotContext, id: Int) -> #(Dot, DotContext) {
  let clock =
    ctx.clock
    |> dict.upsert(id, fn(i) {
      case i {
        option.Some(v) -> v + 1
        _ -> 1
      }
    })
  let v = ctx.clock |> dict.get(id) |> result.unwrap(1)
  #(#(id, v), DotContext(clock:, cloud: ctx.cloud))
}

fn ctx_merge(a: DotContext, b: DotContext) {
  let clock = vector_clock_merge(a.clock, b.clock)
  let cloud = a.cloud |> set.union(b.cloud)
  DotContext(clock:, cloud:) |> ctx_compact
}

// merge 2 vector clock by taking the max of each value for duplicate keys
fn vector_clock_merge(a: VectorClock, b: VectorClock) {
  b
  |> dict.fold(a, fn(acc, kb, vb) {
    acc
    |> dict.upsert(kb, fn(i) {
      case i {
        option.Some(v) -> int.max(v, vb)
        _ -> vb
      }
    })
  })
}

// Traverse for each dot in a dot cloud:
// -> Check if a dot is no longer detached - 
//    if its sequence number is exactly one more than its replica 
//    counterpart in vector clock, it means that this event is 
//    actually continuous, so it can be joined to vector clock.
// -> Check if a dot's sequence number is less than or equal 
//    than its counterpart in vector clock - if it's so, it has been 
//    already represented inside vector clock itself, so we no longer need it.
// -> If dot doesn't match cases 1. or 2., it remains detached, so it should stay in a dot cloud.
// TODO: Do we need a sorted set here or only used list and use 'sorted_add' ?
// Maybe we can use https://www.erlang.org/doc/apps/stdlib/orddict.html ?
fn ctx_compact(ctx: DotContext) {
  let #(clock, to_remove) =
    ctx.cloud
    |> set.to_list
    |> list.sort(fn(left, right) {
      // order by count of replica
      let #(_, ln) = left
      let #(_, rn) = right
      ln |> int.compare(rn)
    })
    |> set.from_list
    |> set.fold(#(ctx.clock, set.new()), fn(acc, item) {
      let #(id, num) = item
      let #(clock, to_remove) = acc
      let num_2 = clock |> dict.get(id) |> result.unwrap(0)
      case num == num_2 + 1, num <= num_2 {
        True, _ -> {
          #(clock |> dict.insert(id, num), to_remove |> set.insert(#(id, num)))
        }
        False, True -> {
          #(clock, to_remove |> set.insert(#(id, num)))
        }
        _, _ -> #(ctx.clock, to_remove)
      }
    })
  DotContext(clock:, cloud: ctx.cloud |> set.drop(to_remove |> set.to_list))
}
