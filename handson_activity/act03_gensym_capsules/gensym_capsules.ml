(* The aim of this activity is to understand how to use capsules. We're going to
   stick with the non-atomic references in `gensym`. Use capsules to ensure that
   gensym is safe for parallel access (and the code will compile). *)

open Await

(* Here is an example snippet to show how to create and use capsules. *)
let safe_ref (init : int) =
  (* Create a capsule guarded by a mutex and extract the latter *)
  let (P mutex) = Capsule.Mutex.create () in
  (* Create encapsulated data bound to the same key type *)
  let r = Capsule.Data.create (fun () -> ref init) in

  (* Access with lock *)
  let read (w : Await.t) =
    Capsule.Mutex.with_lock w mutex ~f:(fun access ->
      let r = Capsule.Data.unwrap r ~access in !r)
  in
  let write (w : Await.t) v =
    Capsule.Mutex.with_lock w mutex ~f:(fun access ->
      let r = Capsule.Data.unwrap r ~access in r := v)
  in
  (read, write)

let gensym =
  let counter = ref 0 in
  fun () ->
    counter := !counter + 1;
    Printf.sprintf "gsym_%d" !counter

let parallel_read_write par =
  let r = safe_ref 0 in
  let read, write = r in
  let #((), ()) = 
    Parallel.fork_join2 par
      (fun _ -> Await_blocking.with_await Terminator.never ~f:(fun w ->
        for _ = 1 to 1000 do
          ignore (read w)
        done))
      (fun _ -> Await_blocking.with_await Terminator.never ~f:(fun w ->
        for i = 1 to 1000 do
          write w i
        done))
  in ()

(* Test that gensym produces distinct symbols in parallel *)

let gensym_pair par =
  let #(s1, s2) =
    Parallel.fork_join2 par (fun _ -> gensym ()) (fun _ -> gensym ())
  in
  assert (s1 <> s2)

(* Run parallel computation *)
let run_parallel ~f =
  let module Scheduler = Parallel_scheduler in
  let scheduler = Scheduler.create () in
  let result = Scheduler.parallel scheduler ~f in
  Scheduler.stop scheduler;
  result

let () =
  run_parallel ~f:parallel_read_write;
  run_parallel ~f:gensym_pair
