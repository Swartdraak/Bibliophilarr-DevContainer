---
name: coder-capabilities
description: Evaluate supported APIs, native MCP, workspace APIs, template APIs, and policy-gated actions.
---

# Coder Capabilities

## Purpose

Use this skill to separate supported operations from unsupported ones.

## Steps

1. Inspect CLI and server capability evidence.
2. Confirm whether native MCP exists.
3. Determine if a requested change is read-only, reversible, or high risk.
4. Choose the least risky supported path.