(rule
 (targets v0.ml)
 (deps
   v0/s.ml
   v0/option.ml
   v0/mBytes.ml
 )

(action (with-stdout-to %{targets} (chdir %{workspace_root}}
 (run %{libexec:tezos-protocol-environment-packer:s_packer} "structs" %{deps})))))
