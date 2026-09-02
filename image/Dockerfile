# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=ubuntu:24.04@sha256:353675e2a41babd526e2b837d7ec780c2a05bca0164f7ea5dbbd433d21d166fc
FROM ${BASE_IMAGE}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG NODE_MAJOR=20
ARG DOTNET_CHANNEL=8.0
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git git-lfs jq ripgrep fd-find tree unzip zip tar gzip \
    openssh-client gnupg lsof procps iproute2 dnsutils netcat-openbsd shellcheck \
    python3 python3-venv pipx sudo && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd
RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/ms.deb \
 && dpkg -i /tmp/ms.deb && rm /tmp/ms.deb && apt-get update \
 && apt-get install -y --no-install-recommends dotnet-sdk-${DOTNET_CHANNEL} powershell \
 && rm -rf /var/lib/apt/lists/*
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" >/etc/apt/sources.list.d/nodesource.list \
 && apt-get update && apt-get install -y --no-install-recommends nodejs \
 && corepack enable && rm -rf /var/lib/apt/lists/*
# ubuntu:24.04 ships with an `ubuntu` user at UID/GID 1000. Coder workspaces
# expect the `coder` user to be the primary UID 1000 user, so remove the
# placeholder user BEFORE creating `coder`. Use `userdel` WITHOUT -r so group
# GID 1000 is preserved (removing it would make `useradd --gid 1000` fail),
# then drop the leftover home directory.
RUN set -eux; \
    # Remove the placeholder user that occupies UID/GID 1000 on ubuntu:24.04. \
    # `userdel` may also remove the now-empty GID 1000 group, so we guarantee \
    # the group exists again before creating `coder`.
    if getent passwd 1000 >/dev/null 2>&1; then \
      existing=$(getent passwd 1000 | cut -d: -f1); \
      userdel "$existing" || true; \
      rm -rf "/home/$existing" 2>/dev/null || true; \
    fi; \
    if getent group 1000 >/dev/null 2>&1; then \
      groupdel "$(getent group 1000 | cut -d: -f1)" || true; \
    fi; \
    groupadd --gid 1000 coder; \
    useradd --create-home --shell /bin/bash --uid 1000 --gid 1000 coder; \
    echo 'coder ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/coder; \
    chmod 0440 /etc/sudoers.d/coder; \
    install -d -o coder -g coder /workspaces \
      /home/coder/.cache/nuget /home/coder/.cache/yarn /home/coder/.cache/node \
      /home/coder/.cache/copilot
RUN curl -fsSL https://get.docker.com | sh \
 && usermod -aG docker coder
# GitHub CLI (gh) from GitHub's official apt repository. Required by
# verify-workspace.sh and used by the repository agent workflows.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*
# GitHub Copilot CLI (agentic BYOK against the local vLLM endpoint, Phase 41).
# Official package per https://github.com/features/copilot/cli : npm install -g @github/copilot.
# Best-effort: a transient registry failure must not be allowed to fail the
# whole image build; runtime tooling reports copilot as NOT-AVAILABLE if missing.
RUN (npm install -g @github/copilot && echo 'copilot-cli installed') \
  || echo 'WARNING: Copilot CLI install failed; continuing build'
# OpenAI Codex CLI (§13/§14 development tooling). Official package:
# https://github.com/openai/codex : npm install -g @openai/codex.
# PINNED to 0.152.1 (latest stable as of 2026-09-02) - per the deterministic
# toolchain policy, no floating "latest". Requires Node >= 18 (we ship 20.x).
#
# IMPORTANT BACKEND NOTE (§14, accurate not fabricated): Codex CLI authenticates
# via a ChatGPT plan sign-in OR an OPENAI_API_KEY against api.openai.com. It does
# NOT natively point at an arbitrary OpenAI-compatible base URL, so it is NOT the
# consumer of the local Qwen/vLLM endpoint. The workspace's intended inference
# backend (local Qwen/vLLM at 192.168.100.102:8000) is used by the Copilot CLI
# and the Bibliophilarr custom agents - NOT by Codex. Codex presence +
# `codex --version` is the acceptance target (§31); a functional Codex call
# requires independent OpenAI auth which is out of scope for this profile.
# Best-effort install (as with copilot): a transient registry failure must not
# break the image build; runtime tooling reports codex as NOT-AVAILABLE if missing.
RUN (npm config set prefix /usr/local \
    && npm install -g @openai/codex@0.152.1 \
    && echo 'codex-cli installed') \
  || echo 'WARNING: Codex CLI install failed; continuing build'
RUN ln -sf /usr/local/bin/codex /usr/bin/codex

# FIX (§29 code-server): the base image leaves /home/coder/.cache owned by
# root, so code-server's auto-install (running as the coder user) fails with
# "mkdir: cannot create directory ~/.cache/code-server: Permission denied",
# which Coder reports as an agent startup error. Pre-create the exact cache
# dirs code-server, gh and dotnet use, owned by coder, before switching the
# user. (A plain `chown -R` of the whole home is not used because it is
# unreliable on build cache layers; creating the specific dirs is deterministic.)
RUN mkdir -p /home/coder/.cache/code-server /home/coder/.config/gh /home/coder/.nuget \
    && chown -R coder:coder /home/coder/.cache /home/coder/.config /home/coder/.nuget
COPY scripts/ /opt/workspace/bin/
COPY image/scripts/ /opt/workspace/bin/
COPY workspace/bin/ /opt/workspace/bin/
RUN chmod 0755 /opt/workspace/bin/* && ln -s /opt/workspace/bin/* /usr/local/bin/
ENV WORKSPACE_IMAGE_VERSION=0.2.6
USER coder
WORKDIR /workspaces
# Coder agent pattern (root cause of "agent never connects", proven 2026-09-02):
# Coder injects its agent bootstrap as the container COMMAND (["sh","-c",
# coder_agent.main.init_script]). Docker runs `ENTRYPOINT` + `CMD`. The previous
# ENTRYPOINT (a `while :; do sleep 3600; done` keep-alive) ran as PID 1 and
# silently DISCARDED the Coder command, so `coder agent` was never started and
# the agent stuck in "connecting" forever.
#
# Fix: EMPTY ENTRYPOINT so Coder's command runs directly; a CMD keep-alive only
# as a fallback when NO command is supplied (manual `docker run`). Coder always
# supplies a command, so the agent (which ends in `exec ./coder agent`, becoming
# PID 1) keeps the container alive normally. Never re-add an ENTRYPOINT that
# swallows the command.
ENTRYPOINT []
CMD ["/bin/sh", "-c", "trap 'exit 0' TERM; while :; do sleep 3600 & wait $!; done"]
