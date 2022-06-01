(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@mineplex.com>     *)
(* Copyright (c) 2019 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

(** This module maintains several pools of points/peers needed by the P2P layer.

    Recall a *point id* (or point) is a couple (addr, port). A *peer id*
    (or peer) is a hash uniquely identifying a peer. An address may host
    several peers.

    Pool functions can trigger two types of events. They can *log*
    [P2p_connection.P2p_event.t] (for the upper layer), and they can
    trigger condition variables defined in [P2p_trigger.t], for inter-modules
    synchronization. *)

(** {1 Pool management} *)

(** The type of a pool of connections, parametrized by, resp., the type
    of messages and the meta-information associated to an identity and
    a connection. *)
type ('msg, 'peer, 'conn) t

type config = {
  identity : P2p_identity.t;  (** Our identity. *)
  trusted_points : P2p_point.Id.t list;
      (** List of hard-coded known peers to bootstrap the network from. *)
  peers_file : string;
      (** The path to the JSON file where the metadata associated to
      peer_ids are loaded / stored. *)
  private_mode : bool;
      (** If [true], only open outgoing/accept incoming connections
      to/from peers whose addresses are in [trusted_peers], and inform
      these peers that the identity of this node should not be revealed to
      the rest of the network. *)
  max_known_points : (int * int) option;
      (** Parameters for the garbage collection of known points. If
      None, no garbage collection is performed. Otherwise, the first
      integer of the couple limits the size of the "known points"
      table. When this number is reached, the table is purged off of
      disconnected points, older first, to try to reach the amount of
      connections indicated by the second integer. *)
  max_known_peer_ids : (int * int) option;
      (** Like [max_known_points], but for known peer_ids. *)
}

val create :
  config ->
  'peer P2p_params.peer_meta_config ->
  P2p_trigger.t ->
  log:(P2p_connection.P2p_event.t -> unit) ->
  ('msg, 'peer, 'conn) t Lwt.t

(** [destroy pool] returns when member connections are either
    disconnected or canceled. *)
val destroy : ('msg, 'peer, 'conn) t -> unit Lwt.t

(** [config pool] is the [config] argument passed to [pool] at
    creation. *)
val config : _ t -> config

(** {1 Connections management} *)

(** [active_connections pool] is the number of connections inside
    [pool]. *)
val active_connections : ('msg, 'peer, 'conn) t -> int

(** If [point] doesn't belong to the table of known points,
    [register_point t point] creates a [P2p_point_state.Info.t], triggers a
    `New_point` event and signals the `new_point` condition. If table capacity
    is exceeded, a GC of the table is triggered.

    If [point] is already known, the [P2p_point_state.Info.t] from the table
    is returned. In either case, the trusted status of the returned
    [P2p_point_state.Info.t] is set to [trusted]. *)
val register_point :
  ?trusted:bool ->
  ('msg, 'peer, 'conn) t ->
  P2p_point.Id.t ->
  ('msg, 'peer, 'conn) P2p_conn.t P2p_point_state.Info.t

(** Remove a [point] from the table of known points if it is already known.. *)
val unregister_point : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit

(** [register_new_point pool point] returns [None] if [point] is a point for
    this peer. Otherwise it behaves as [register_point]. *)
val register_new_point :
  ?trusted:bool ->
  ('msg, 'peer, 'conn) t ->
  P2p_point.Id.t ->
  ('msg, 'peer, 'conn) P2p_conn.t P2p_point_state.Info.t option

(** [register_list_of_new_point ?trusted medium source pool point_list]
o    registers all points of the list as new points.
    [medium] and  [source] are for logging purpose. [medium] should indicate
    through which medium the points have been acquired (
    advertisement, Nack, ..)  and [source] is the id of the peer which
    sent the list.
 *)
val register_list_of_new_points :
  ?trusted:bool ->
  medium:string ->
  source:P2p_peer.Id.t ->
  ('msg, 'peer, 'conn) t ->
  P2p_point.Id.t list ->
  unit

(** If [peer] doesn't belong to the table of known peers,
    [register_peer t peer] creates a [P2p_peer.Info.t], triggers a
    `New_peer` event, and signals a `new_peer` condition. If table capacity
    is exceeded, a GC of the table is triggered. If [peer] is already known,
    the [P2p_peer.Info.t] from the table is returned. *)
val register_peer :
  ('msg, 'peer, 'conn) t ->
  P2p_peer.Id.t ->
  (('msg, 'peer, 'conn) P2p_conn.t, 'peer, 'conn) P2p_peer_state.Info.t

module Connection : sig
  val fold :
    ('msg, 'peer, 'conn) t ->
    init:'a ->
    f:(P2p_peer.Id.t -> ('msg, 'peer, 'conn) P2p_conn.t -> 'a -> 'a) ->
    'a

  val list :
    ('msg, 'peer, 'conn) t ->
    (P2p_peer.Id.t * ('msg, 'peer, 'conn) P2p_conn.t) list

  val find_by_point :
    ('msg, 'peer, 'conn) t ->
    P2p_point.Id.t ->
    ('msg, 'peer, 'conn) P2p_conn.t option

  val find_by_peer_id :
    ('msg, 'peer, 'conn) t ->
    P2p_peer.Id.t ->
    ('msg, 'peer, 'conn) P2p_conn.t option

  (** [random_addr ?conn no_private t] returns a random (point_id, peer_id)
      from the pool of connections. It ignores:
      - connections to private peers if [no_private] is set to [true]
      - connection [conn]
      - connections to peers who didn't provide a listening port at
        session-establishment *)
  val random_addr :
    ?different_than:('msg, 'peer, 'conn) P2p_conn.t ->
    no_private:bool ->
    ('msg, 'peer, 'conn) t ->
    (P2p_point.Id.t * P2p_peer.Id.t) option

  (** [propose_swap_request t] returns a triple (point_id, peer_id, conn) where
        conn is a random connection to a non-private peer, and (point_id, peer_id)
        is a random, different, connected peer_id at point_id.  *)
  val propose_swap_request :
    ('msg, 'peer, 'conn) t ->
    (P2p_point.Id.t * P2p_peer.Id.t * ('msg, 'peer, 'conn) P2p_conn.t) option
end

(** {1 Functions on [Peer_id]} *)

module Peers : sig
  type ('msg, 'peer, 'conn) info =
    (('msg, 'peer, 'conn) P2p_conn.t, 'peer, 'conn) P2p_peer_state.Info.t

  val info :
    ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> ('msg, 'peer, 'conn) info option

  val get_peer_metadata : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> 'peer

  val set_peer_metadata :
    ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> 'peer -> unit

  val get_score : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> float

  val fold_known :
    ('msg, 'peer, 'conn) t ->
    init:'a ->
    f:(P2p_peer.Id.t -> ('msg, 'peer, 'conn) info -> 'a -> 'a) ->
    'a

  val fold_connected :
    ('msg, 'peer, 'conn) t ->
    init:'a ->
    f:(P2p_peer.Id.t -> ('msg, 'peer, 'conn) info -> 'a -> 'a) ->
    'a

  val add_connected :
    ('msg, 'peer, 'conn) t ->
    P2p_peer.Id.t ->
    (('msg, 'peer, 'conn) P2p_conn.t, 'peer, 'conn) P2p_peer_state.Info.t ->
    unit

  val remove_connected : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit

  (** [ban t peer_id] blacklists this peer_id and terminates connection
      (if any). *)
  val ban : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit Lwt.t

  (** [unban t peer_id] removes this peer_id from the black list. *)
  val unban : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit

  (** [banned t peer_id] returns [true] if the peer is in the black list. *)
  val banned : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> bool

  (** [get_trusted t peer_id] returns [false] if this peer isn't known.
      Otherwise it calls [trusted] for this peer info. *)
  val get_trusted : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> bool

  (** [trust t peer_id] sets the peer info for this peer to trusted, and
      [unban] it. The peer is registered first if not known (see
      [register_peer]). *)
  val trust : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit

  (** [untrust t peer_id] set the peer info for this peer to not trusted.
      Does nothing if this peer isn't known. *)
  val untrust : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit
end

(** {1 Functions on [Points]} *)

module Points : sig
  type ('msg, 'peer, 'conn) info =
    ('msg, 'peer, 'conn) P2p_conn.t P2p_point_state.Info.t

  val info :
    ('msg, 'peer, 'conn) t ->
    P2p_point.Id.t ->
    ('msg, 'peer, 'conn) info option

  val fold_known :
    ('msg, 'peer, 'conn) t ->
    init:'a ->
    f:(P2p_point.Id.t ->
      ('msg, 'peer, 'conn) P2p_conn.t P2p_point_state.Info.t ->
      'a ->
      'a) ->
    'a

  val fold_connected :
    ('msg, 'peer, 'conn) t ->
    init:'a ->
    f:(P2p_point.Id.t -> ('msg, 'peer, 'conn) info -> 'a -> 'a) ->
    'a

  val add_connected :
    ('msg, 'peer, 'conn) t ->
    P2p_point.Id.t ->
    ('msg, 'peer, 'conn) P2p_conn.t P2p_point_state.Info.t ->
    unit

  val remove_connected :
    ('msg, 'peer, 'conn) t -> 'd P2p_point_state.Info.t -> unit

  (** [ban t point_id] marks the address of this point_id as blacked-listed.
      it disconnects all connections to this address. This [port_id]'s port is
      ignored. *)
  val ban : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit Lwt.t

  (* TODO this isn't consistent with greylist functions where only an addr is
     provided). *)

  (** [ban t point_id] removes this point address from the black list.
      This [point_id]'s port is ignored. *)
  val unban : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit

  (** [banned t point_id] returns [true] if the point addr is in the black list.
      This [point_id]'s port is ignored. *)
  val banned : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> bool

  (** [get_trusted t point_id] returns [false] if this point isn't known.
      Otherwise it calls [trusted] for this peer info. *)
  val get_trusted : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> bool

  (** [trust t point_id] sets the point info for this point to trusted.
      The point is registered first if not known (see [register_point]). *)
  val trust : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit

  (** [untrust t point_id] sets the point info peer info for this point
      to not trusted. Does nothing if point isn't known. *)
  val untrust : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit
end

(** {1 Misc functions} *)

(** [greylist_addr pool addr] adds [addr] to [pool]'s IP greylist. *)
val greylist_addr : ('msg, 'peer, 'conn) t -> P2p_addr.t -> unit

(** [greylist_peer pool peer] adds [peer] to [pool]'s peer greylist
    and [peer]'s address to [pool]'s addr greylist. *)
val greylist_peer : ('msg, 'peer, 'conn) t -> P2p_peer.Id.t -> unit

(** [gc_greylist ~older_than pool] removes addresses older than [older_than]
    from the greylist. *)
val gc_greylist : older_than:Time.System.t -> ('msg, 'peer, 'conn) t -> unit

(** [acl_clear pool] clears ACL tables. *)
val acl_clear : ('msg, 'peer, 'conn) t -> unit

(** [list_known_points ~ignore_private t] returns a list of point ids,
    which are not banned, and if [ignore_private] is [true], public.

    It returns at most [size] point ids (default is 50) based on a
    heuristic that selects a mix of 3/5 "good" and 2/5 random points. *)
val list_known_points :
  ignore_private:bool ->
  ?size:int ->
  ('msg, 'peer, 'coon) t ->
  P2p_point.Id.t list Lwt.t

val connected_peer_ids :
  ('msg, 'peer, 'conn) t ->
  (('msg, 'peer, 'conn) P2p_conn.t, 'peer, 'conn) P2p_peer_state.Info.t
  P2p_peer.Table.t

(** [score t peer_meta] returns the score of [peer_meta]. *)
val score : ('msg, 'peer, 'conn) t -> 'peer -> float

(** [add_to_id_points t point] adds [point] to the list of points for this
    peer. [point] is removed from the list of known points. *)
val add_to_id_points : ('msg, 'peer, 'conn) t -> P2p_point.Id.t -> unit
