import gcrdt/dot
import gcrdt/replica
import gleam/option.{type Option, None, Some}

/// Delta-aware Add-Wins Observed Remove Set
pub type Awor(a) {
  Awor(kernel: dot.DotKernel(a), delta: Option(dot.DotKernel(a)))
}

pub fn new() {
  Awor(dot.new(), None)
}

pub fn value(awor: Awor(a)) {
  awor.kernel |> dot.values
}

pub fn add(awor: Awor(a), value: a, id: replica.ReplicaId) {
  let delta = option.unwrap(awor.delta, dot.new())
  let #(kernel, delta) = awor.kernel |> dot.remove(delta, value)
  let #(kernel, delta) = kernel |> dot.add(delta, value, id)
  Awor(kernel: kernel, delta: Some(delta))
}

pub fn remove(awor: Awor(a), value: a) {
  let delta = option.unwrap(awor.delta, dot.new())
  let #(kernel, delta) = awor.kernel |> dot.remove(delta, value)
  Awor(kernel: kernel, delta: Some(delta))
}

pub fn merge(a: Awor(a), b: Awor(a)) {
  let delta = Some(merge_option(a.delta, b.delta))
  let kernel = dot.merge(a.kernel, b.kernel)
  Awor(kernel:, delta:)
}

pub fn merge_delta(a: Awor(a), delta: dot.DotKernel(a)) {
  let dc = Some(merge_option(a.delta, Some(delta)))
  let kernel = dot.merge(a.kernel, delta)
  Awor(kernel:, delta: dc)
}

fn merge_option(a: Option(dot.DotKernel(a)), b: Option(dot.DotKernel(a))) {
  dot.merge(option.unwrap(a, dot.new()), option.unwrap(b, dot.new()))
}
