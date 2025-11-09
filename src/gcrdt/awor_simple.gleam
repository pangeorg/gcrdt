import gcrdt/replica
import gcrdt/vtime
import gleam/dict

// Add-Wins Observed Remove Set 
pub type AworSimple(a) {
  Awor(add: dict.Dict(a, vtime.VTime), rem: dict.Dict(a, vtime.VTime))
}

pub fn new() {
  Awor(dict.new(), dict.new())
}

/// Returns the add set with items removed whoose timestap is SMALLER than
/// the respective ones in the remove set
pub fn value(awor: AworSimple(a)) {
  awor.rem
  |> dict.fold(awor.add, fn(acc, kr, vr) {
    case dict.get(acc, kr) {
      Ok(va) ->
        case va |> vtime.compare(vr) {
          vtime.Lt -> acc |> dict.drop([kr])
          _ -> acc
        }
      _ -> acc
    }
  })
}

pub fn add(awor: AworSimple(a), item: a, id: replica.ReplicaId) {
  let #(add, rem) = {
    case dict.get(awor.add, item), dict.get(awor.rem, item) {
      Ok(avtime), _ -> #(
        awor.add |> dict.insert(item, vtime.inc(avtime, id)),
        awor.rem |> dict.drop([item]),
      )
      _, Ok(rvtime) -> #(
        awor.add |> dict.insert(item, vtime.inc(rvtime, id)),
        awor.rem |> dict.drop([item]),
      )
      _, _ -> #(
        awor.add |> dict.insert(item, vtime.new() |> vtime.inc(id)),
        awor.rem |> dict.drop([item]),
      )
    }
  }
  Awor(add, rem)
}

pub fn remove(awor: AworSimple(a), item: a, id: replica.ReplicaId) {
  let #(add, rem) = {
    case dict.get(awor.add, item), dict.get(awor.rem, item) {
      Ok(avtime), _ -> #(
        awor.add |> dict.drop([item]),
        awor.rem |> dict.insert(item, vtime.inc(avtime, id)),
      )
      _, Ok(rvtime) -> #(
        awor.add |> dict.drop([item]),
        awor.rem |> dict.insert(item, vtime.inc(rvtime, id)),
      )
      _, _ -> #(
        awor.add |> dict.drop([item]),
        awor.rem |> dict.insert(item, vtime.new() |> vtime.inc(id)),
      )
    }
  }
  Awor(add, rem)
}

pub fn merge(a: AworSimple(a), b: AworSimple(a)) {
  let add_k = merge_keys(a.add, b.add)
  let rem_k = merge_keys(a.rem, b.rem)

  // remove entries from add_k whoose timestamps are lower than
  // the corresponding entries in rem_k

  let add =
    rem_k
    |> dict.fold(add_k, fn(acc, kr, vr) {
      case acc |> dict.get(kr) {
        Ok(va) ->
          case va |> vtime.compare(vr) {
            vtime.Lt -> dict.drop(acc, [kr])
            _ -> acc
          }
        _ -> acc
      }
    })

  // remove entries from the remove set whoose entries are Lt, Eq or Cc to the
  // correstonding ones in add_k

  let rem =
    add_k
    |> dict.fold(rem_k, fn(acc, ka, va) {
      case acc |> dict.get(ka) {
        Ok(vr) ->
          case vr |> vtime.compare(va) {
            vtime.Lt -> acc
            _ -> dict.drop(acc, [ka])
          }
        _ -> dict.drop(acc, [ka])
      }
    })

  Awor(add:, rem:)
}

fn merge_keys(
  a_keys: dict.Dict(a, vtime.VTime),
  b_keys: dict.Dict(a, vtime.VTime),
) {
  b_keys
  |> dict.fold(a_keys, fn(acc, kb, vb) {
    case acc |> dict.get(kb) {
      Ok(va) -> acc |> dict.insert(kb, vtime.merge(va, vb))
      _ -> acc |> dict.insert(kb, vb)
    }
  })
}
