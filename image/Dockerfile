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
RUN curl -fsSL https://get.docker.com | sh
RUN existing=$(getent passwd 1000 | cut -d: -f1); \
    if [ -n "$existing" ]; then userdel --remove "$existing"; fi; \
    useradd --create-home --shell /bin/bash --uid 1000 coder \
 && echo 'coder ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/coder \
 && chmod 0440 /etc/sudoers.d/coder \
 && install -d -o coder -g coder /workspaces /home/coder/.cache/nuget /home/coder/.cache/yarn
COPY scripts/ /opt/workspace/bin/
COPY image/scripts/ /opt/workspace/bin/
COPY workspace/bin/ /opt/workspace/bin/
RUN chmod 0755 /opt/workspace/bin/* && ln -s /opt/workspace/bin/* /usr/local/bin/
ENV WORKSPACE_IMAGE_VERSION=0.2.0
USER coder
WORKDIR /workspaces
ENTRYPOINT ["/bin/sh", "-c", "trap 'exit 0' TERM; while :; do sleep 3600 & wait $!; done"]
