# Local LLM

Non-secret parameters map to `LOCAL_LLM_PROVIDER`, `LOCAL_LLM_BASE_URL`, `LOCAL_LLM_MODEL`, and
`LOCAL_LLM_CONTEXT_LENGTH`. `LOCAL_LLM_API_KEY` must come from a least-scoped Coder user secret or an
external broker after its live scope is audited. It must not enter Terraform state. Validator identities
must not inherit the deployment API token or unrelated user secrets.

`verify-local-llm` validates exact model presence, completion, SSE streaming, and a required function call.
The context-length value is reported/configured but a destructive maximum-context allocation is avoided;
the configured model/server limit must be inspected during live acceptance. The interactive orchestrator
delegation prompt is an acceptance procedure, not automated product QA, because only the repository's
actual agent-capable client can prove delegation.
