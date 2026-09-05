# Configuration

The canonical example configuration is `coderops/coderops.example.yaml`.

## Precedence

1. CLI arguments
2. environment variables
3. user configuration
4. repository default configuration
5. built-in defaults

## Important fields

- `mode`: observer, operator, or administrator
- `coder.urlFromEnv`: the environment variable that carries the Coder URL
- `coder.auth.mode`: how authentication is sourced
- `repository.root`: repository root path used by inventory and drift checks
- `policy.allowR3` / `policy.allowR4`: high-risk enablement flags