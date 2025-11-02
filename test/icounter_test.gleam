import gcrdt/icounter

pub fn icounter_inc_test() {
  let c =
    icounter.new() |> icounter.inc(1) |> icounter.inc(1) |> icounter.inc(1)
  assert c |> icounter.value == 3
}

pub fn icounter_merge_test() {
  let c1 =
    icounter.new() |> icounter.inc(1) |> icounter.inc(1) |> icounter.inc(1)
  let c2 = icounter.new() |> icounter.inc(2) |> icounter.inc(2)
  let c3 = icounter.new() |> icounter.inc(3) |> icounter.inc(3)
  let m = icounter.merge_all([c1, c2, c3])
  assert m |> icounter.value == 7
}
