open Internal_pervasives

type t =
  { level: int
  ; protocol_hash: string
  ; name: string
  ; baker: mineplex_executable.t
  ; endorser: mineplex_executable.t
  ; accuser: mineplex_executable.t }

let cmdliner_term base_state ~docs ?(prefix = "hard-fork") () =
  let open Cmdliner in
  let open Cmdliner.Term in
  let extra_doc = Fmt.str " for the hard-fork (requires --%s)" prefix in
  pure (fun hard_fork baker endorser accuser ->
      Option.map hard_fork ~f:(fun (level, protocol_hash) ->
          {level; name= prefix; protocol_hash; baker; endorser; accuser}))
  $ Arg.(
      value
        (opt
           (some (pair ~sep:':' int string))
           None
           (info [prefix] ~doc:"Make a hard-fork happen" ~docs
              ~docv:"LEVEL:PROTOCOL-HASH")))
  $ mineplex_executable.cli_term ~extra_doc base_state `Baker prefix
  $ mineplex_executable.cli_term ~extra_doc base_state `Endorser prefix
  $ mineplex_executable.cli_term ~extra_doc base_state `Accuser prefix

let executables {baker; endorser; accuser; _} = [baker; endorser; accuser]

let node_network_config t =
  let open Ezjsonm in
  ( "user_activated_upgrades"
  , list Fn.id
      [ dict
          [ ("level", int t.level)
          ; ("replacement_protocol", string t.protocol_hash) ] ] )

let keyed_daemons t ~client ~key ~node =
  [ mineplex_daemon.baker_of_node ~name_tag:t.name ~exec:t.baker ~client node ~key
  ; mineplex_daemon.endorser_of_node ~name_tag:t.name ~exec:t.endorser ~client
      node ~key ]
