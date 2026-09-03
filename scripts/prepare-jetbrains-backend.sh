#!/usr/bin/env bash
# prepare-jetbrains-backend.sh — §8 deterministic JetBrains remote-backend layout.
#
# Coder's JetBrains module (v1.4.0) only sets a jetbrains:// Toolbox URI with
# pinned IDE builds; it has NO env/config/plugin-install hook. On first connect,
# Gateway downloads the IDE build into ~/.cache/JetBrains/RemoteDev and installs
# per-project state, which is what produces the "launches, fails, re-downloads /
# Channel closed / executor rejected" churn when the backend state is not
# persistent or was wiped.
#
# Fix: pin the backend dirs to the PERSISTENT home volume via <product>.*.path
# env vars (set in the coder_agent env) AND pre-create those dirs here so the
# very first connect has a clean, expected, owned-by-coder layout. Because they
# live on the home volume, stop/start (and reconnects) reuse them instead of
# reinstalling. A delete/recreate workspace re-seeds this deterministically.
#
# This does NOT install the IDE build (Gateway owns that; it is pinned/air-gapped
# via ide_config) and does NOT auto-sign-in the third-party GitHub Copilot
# plugin (that requires interactive GitHub device auth — see report). It only
# guarantees the persistent directory skeleton + ownership.
set -euo pipefail
home=${CODER_HOME:-/home/coder}
mkdir -p \
  "$home/.config/JetBrains/Rider" \
  "$home/.local/share/JetBrains/Rider" \
  "$home/.cache/JetBrains/Rider/log" \
  "$home/.config/JetBrains/WebStorm" \
  "$home/.local/share/JetBrains/WebStorm" \
  "$home/.cache/JetBrains/WebStorm/log"
# The backend runs as the coder user (uid 1000); ensure it owns the tree.
if [[ "$(id -u)" -eq 1000 ]]; then
  chown -R 1000:1000 \
    "$home/.config/JetBrains" "$home/.local/share/JetBrains" "$home/.cache/JetBrains" 2>/dev/null || true
fi
echo "prepare-jetbrains-backend: persistent backend dirs ready under $home (Rider + WebStorm)"
