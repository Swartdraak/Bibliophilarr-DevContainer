---
name: coder-security
description: Audit permissions, redaction, path traversal, shell safety, and destructive-operation controls.
---

# Coder Security

## Purpose

Use this skill for secret safety, least-privilege review, and mutation gating.

## Rules

- redact secrets
- reject arbitrary shell execution
- require explicit approval for high risk actions
- preserve audit evidence