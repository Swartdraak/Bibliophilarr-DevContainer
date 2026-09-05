---
name: coder-discovery
description: Discover Coder server version, CLI behavior, authentication state, and native MCP availability.
---

# Coder Discovery

## Purpose

Use this skill to determine what the live Coder deployment can actually do before any operational decision.

## When to use

- version-dependent behavior matters
- auth or CLI state is unknown
- native MCP availability must be verified

## Checks

- `coder version`
- `coder --help`
- `coder exp mcp --help`
- `coder whoami`

## Outcome

Return a factual capability snapshot. Unknown is acceptable; assumptions are not.