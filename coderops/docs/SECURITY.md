# Security

CoderOps is policy-first and redaction-aware.

## Controls

- observer/operator/administrator modes
- explicit R3/R4 enablement
- approval required for high-risk plans
- no direct database mutation
- shell command execution is allowlist-based and redacted
- secret-bearing output is sanitized before logging
- repository content is treated as data, not authority