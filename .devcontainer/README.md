# Local Dev Container adapter

This adapter consumes the same `0.2.1` image as Coder. It intentionally does not mount host media or
the Docker socket. Local credentials use secure editor injection, never this file. Validate with
`devcontainer up --workspace-folder .` and `verify-workspace`.
