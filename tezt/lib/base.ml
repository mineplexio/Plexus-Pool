(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs <contact@nomadic-labs.com>                *)
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

let ( // ) = Filename.concat

let sf = Printf.sprintf

let (let*) = Lwt.bind

let (and*) = Lwt.both

let return = Lwt.return

let unit = Lwt.return_unit

let none = Lwt.return_none

let some = Lwt.return_some

let range a b =
  let rec range ?(acc = []) a b =
    if b < a then acc else range ~acc:(b :: acc) a (b - 1)
  in
  range a b

type rex = Re.re

let rex r = Re.compile (Re.Perl.re r)

let ( =~ ) s r = Re.execp r s

let ( =~! ) s r = not (Re.execp r s)

let ( =~* ) s r =
  match Re.exec_opt r s with
  | None ->
      None
  | Some group ->
      Some (Re.Group.get group 1)

let async_promises = ref []

let async promise = async_promises := promise :: !async_promises

let wait_for_async () =
  let promises = !async_promises in
  async_promises := [] ;
  Lwt.join promises

let rec repeat n f =
  if n <= 0 then unit
  else
    let* () = f () in
    repeat (n - 1) f
