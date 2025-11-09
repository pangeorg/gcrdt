import gcrdt/icounter

pub fn icounter_inc_test() {
  let c =
    icounter.new()
    |> icounter.inc("a")
    |> icounter.inc("a")
    |> icounter.inc("a")
  assert c |> icounter.value == 3
}

pub fn icounter_merge_test() {
  let c1 =
    icounter.new()
    |> icounter.inc("a")
    |> icounter.inc("a")
    |> icounter.inc("a")
  let c2 = icounter.new() |> icounter.inc("b") |> icounter.inc("b")
  let c3 = icounter.new() |> icounter.inc("c") |> icounter.inc("c")
  let m = icounter.merge_all([c1, c2, c3])
  assert m |> icounter.value == 7
}
