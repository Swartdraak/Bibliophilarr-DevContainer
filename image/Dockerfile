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
COPY scripts/ /opt/workspace/bin/
COPY image/scripts/ /opt/workspace/bin/
COPY workspace/bin/ /opt/workspace/bin/
RUN chmod 0755 /opt/workspace/bin/* && ln -s /opt/workspace/bin/* /usr/local/bin/
ENV WORKSPACE_IMAGE_VERSION=0.2.1
USER coder
WORKDIR /workspaces
ENTRYPOINT ["/bin/sh", "-c", "trap 'exit 0' TERM; while :; do sleep 3600 & wait $!; done"]
