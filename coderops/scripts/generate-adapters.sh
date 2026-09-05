#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_root=$(cd "$root/.." && pwd)
generated="$root/adapters/generated"
mkdir -p "$generated"
python3 - <<'PY' "$root" "$repo_root"
import pathlib, shutil, sys
root = pathlib.Path(sys.argv[1])
repo_root = pathlib.Path(sys.argv[2])
for source_dir, target_dir in [
  (root / 'agents', repo_root / '.github' / 'agents'),
  (root / 'skills', repo_root / '.github' / 'skills'),
  (root / 'instructions', repo_root / '.github' / 'instructions'),
  (root / 'skills', repo_root / '.agents' / 'skills'),
]:
    target_dir.mkdir(parents=True, exist_ok=True)
    for source in source_dir.rglob('*.md'):
        relative = source.relative_to(source_dir)
        destination = target_dir / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
PY
cat > "$generated/copilot-mcp.json" <<'EOF'
{
  "mcpServers": {
    "coder": {
      "command": "coder",
      "args": ["exp", "mcp", "server"]
    },
    "coderops": {
      "command": "node",
      "args": ["coderops/mcp/dist/server.js"]
    }
  }
}
EOF
cat > "$generated/coder-native-mcp.json" <<'EOF'
{
  "command": "coder",
  "args": ["exp", "mcp", "server"]
}
EOF
cat > "$generated/generic-mcp-profile.json" <<'EOF'
{
  "profiles": {
    "bibliophilarr": ["filesystem", "git", "github", "memory", "sequential-thinking", "coder", "coderops"]
  }
}
EOF
echo "coderops generate-adapters: wrote adapter manifests to $generated"