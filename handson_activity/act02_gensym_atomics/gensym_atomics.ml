(* Exercise 1
   ----------
   Complete the implementation of [gensym_pair] function.
*)

let gensym =
  let counter = ref 0 in
  fun () ->
    counter := !counter + 1;
    Printf.sprintf "gsym_%d" !counter

(* Here's an example of how to use fork_join2 *)
let fork_join_demo par =
  let #(l,r) =
    Parallel.fork_join2 par
      (fun _ -> "left")
      (fun _ -> "right")
  in
  assert (l = "left" && r = "right")

let gensym_pair par =
  (* Generate a pair of symbols using parallel calls to [gensym] using
    [fork_join2].

     Do you need to update [gensym]? Use OxCaml Atomics module:
     (https://github.com/oxcaml/oxcaml/blob/main/stdlib/atomic.mli to get a
     correct implementation.
  *)
  let (s1,s2) = failwith "Not implemented" in
  assert (s1 <> s2)

(* Run parallel computation *)
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler in
  let scheduler = Scheduler.create () in
  let result = Scheduler.parallel scheduler ~f in
  Scheduler.stop scheduler;
  result

let () =
  run_parallel ~f:fork_join_demo;
  run_parallel ~f:gensym_pair
