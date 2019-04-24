(*****************************************************************************)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Nomadic Labs, <contact@nomadic-labs.com>               *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

type Error_monad.error += Proc_stat_failure

let proc_statm () =
  let pid = string_of_int @@ Unix.getpid () in
  let fname = ("/proc/"^pid^"/statm") in
  Lwt_unix.file_exists fname >>= function
  | true ->
      Lwt.catch
        begin fun () -> Lwt_io.open_file ~mode:Input fname   >>= fun ic ->
          Lwt_io.read_line ic >>= fun line ->
          match List.map Int64.of_string @@ String.split ' ' line  with
          | size::resident::shared::text::lib::data::dt::_ ->
              return
                Stat_services.{ size ; resident ; shared ; text ;
                                lib ; data ; dt ; }
          | _ ->  return Stat_services.empty_proc_statm end
        (function _ -> Lwt.return @@ error Proc_stat_failure )
  | false -> return Stat_services.empty_proc_statm

let rpc_directory () =
  let dir = RPC_directory.empty in
  RPC_directory.gen_register dir Stat_services.S.gc_stat begin fun () () () ->
    RPC_answer.return @@ Gc.stat () end |> fun dir ->

  RPC_directory.gen_register dir Stat_services.S.proc_statm begin fun () () () ->
    proc_statm () >>= function
    | Ok statm ->
        RPC_answer.return statm
    | Error errs -> RPC_answer.fail errs end
