output "workspace_name" { value = data.coder_workspace.me.name }
output "requested_ref" { value = data.coder_parameter.bibliophilarr_ref.value }
output "workspace_mode" { value = data.coder_parameter.workspace_mode.value }
