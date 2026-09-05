#!/usr/bin/env bash
# publish-coder-template.sh — repository-first Coder template deployment helper.
#
# Enforces the policy that a template-affecting change is NOT complete until the
# exact repository source has been pushed to Coder, exercised through a fresh
# disposable workspace, and (only if it passes) promoted to active. Git merge
# alone does not deploy.
#
# Design (per docs policy + repository auth conventions):
#   * Loads operator credentials from the repo-local .env via scripts/verify-coder-auth
#     (it NEVER prints tokens; it maps CODER_TOKEN -> CODER_SESSION_TOKEN).
#   * Derives a traceable candidate version name from Git (default git-<short-sha>)
#     or accepts --name so the operator can use the project's vN.N convention.
#   * Runs local validation FIRST (scripts/validate-template.sh).
#   * Pushes the candidate version INACTIVE (--activate=false) — never auto-activates.
#   * Promotes ONLY as an explicit, separate subcommand and ONLY after the
#     operator has validated a fresh workspace (see: create-ws / validate-ws / promote).
#   * NEVER prints secrets. Prints only version names, hosts, and PASS/FAIL.
#
# Subcommands:
#   push       Push the current template directory as a NEW INACTIVE version.
#   plan       Same as push but prints what it WOULD do (no push).
#   create-ws  Create a fresh disposable workspace from a specific version.
#   validate-ws  Print a checklist to run inside the disposable workspace.
#   promote    Promote a validated version to Active.
#   cleanup    Delete the disposable validation workspace.
#   status     Report current active version vs Git HEAD vs image version.
#
# Usage examples:
#   scripts/publish-coder-template.sh push --name v2.2
#   scripts/publish-coder-template.sh create-ws --version v2.2 --ws validation-<sha>
#   scripts/publish-coder-template.sh promote --version v2.2
#   scripts/publish-coder-template.sh cleanup --ws validation-<sha>
#   scripts/publish-coder-template.sh status
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMPLATE_NAME="${CODER_TEMPLATE_NAME:-Bibliophilarr}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$root/template}"
ENV_FILE="${ENV_FILE:-$root/.env}"

# ---------------------------------------------------------------- helpers ----
say()  { printf '%s\n' "$*"; }
ok()   { printf '  [PASS] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
die()  { printf '  [FAIL] %s\n' "$*" >&2; exit 1; }

git_sha_short() { git -C "$root" rev-parse --short HEAD; }
git_head()      { git -C "$root" rev-parse HEAD; }
git_title()     { git -C "$root" log -1 --pretty=%s; }

# Derive a traceable candidate version name.
# If --name given, use it. Else default to git-<short-sha>.
derive_version() { # $1 = explicit name (may be empty)
  if [[ -n ${1:-} ]]; then
    printf '%s' "$1"
  else
    printf 'git-%s' "$(git_sha_short)"
  fi
}

# Load operator credentials from the repo .env (maps CODER_TOKEN->CODER_SESSION_TOKEN).
load_auth() {
  say "Loading operator credentials from $ENV_FILE (values never printed)"
  local out rc
  out=$("$root/scripts/verify-coder-auth" "$ENV_FILE" 2>&1); rc=$?
  # verify-coder-auth prints human-readable diagnostics; show them (no secrets).
  printf '%s\n' "$out" | sed 's/^/  /'
  (( rc == 0 )) || { warn "verify-coder-auth returned rc=$rc"; return "$rc"; }
  export CODER_URL
  export CODER_SESSION_TOKEN
  return 0
}

# Run local validation (terraform fmt/init/validate + shellcheck + json).
run_local_validation() {
  say ""
  say "---- Local validation (scripts/validate-template.sh) ----"
  if "$root/scripts/validate-template.sh"; then
    ok "local validation passed"
  else
    die "local validation FAILED — do not push a broken candidate"
  fi
}

# Return the status of a candidate version name (or ABSENT).
candidate_exists() { # $1 = version name
  local raw name
  raw=$(coder templates versions list "$TEMPLATE_NAME" -o json 2>/dev/null || true)
  name="$1"
  printf '%s' "$raw" | python3 -c '
import sys, json
name = sys.argv[1]
try:
    data = json.loads(sys.stdin.read())
except Exception:
    data = []
for v in data:
    if v.get("name") == name:
        print(v.get("status","?"))
        sys.exit(0)
print("ABSENT")
' "$name"
}

# Parse a simple --flag value / positional helper.
parse_args() {
  VERSION=""; WS=""; NAME=""; DIR="$TEMPLATE_DIR"; MSG=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)          NAME="$2"; shift 2 ;;
      --version)       VERSION="$2"; shift 2 ;;
      --ws)            WS="$2"; shift 2 ;;
      --directory|-d)  DIR="$2"; shift 2 ;;
      --message|-m)    MSG="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  export VERSION WS NAME DIR MSG
}

# ---------------------------------------------------------------- status ----
cmd_status() {
  load_auth || die "auth failed"
  say ""
  say "==== Coder template deployment status ===="
  say "Git HEAD:            $(git_head)  ($(git_sha_short))"
  say "Git title:           $(git_title)"
  say "Template:            $TEMPLATE_NAME"
  say "Image version (env): $(grep -oE 'WORKSPACE_IMAGE_VERSION=[0-9.]+' "$root/image/Dockerfile" | head -1 | cut -d= -f2 || true)"
  say "workspace_image default (variables.tf): ${img_default:-<none>}"
  local img_default
  img_default=$(grep -oE 'ghcr\.io/[^"]+' "$root/template/variables.tf" 2>/dev/null | head -1 || true)
  say ""
  say "Coder versions (most recent first):"
  coder templates versions list "$TEMPLATE_NAME" 2>&1 | head -8 | sed 's/^/  /'
  active=$(coder templates versions list "$TEMPLATE_NAME" 2>/dev/null | awk '/Active/{print $1; exit}')
  say ""
  say "Active version:      ${active:-<none>}"
  if git -C "$root" status --porcelain | grep -q .; then
    say "Working tree clean:  NO (uncommitted changes present)"
  else
    say "Working tree clean:  yes"
  fi
}

# ----------------------------------------------------------------- plan -----
cmd_plan() {
  parse_args "$@"
  load_auth || die "auth failed"
  local v; v=$(derive_version "$NAME")
  say ""
  say "==== PLAN: would push candidate version (dry-run, NO push) ===="
  say "  Template:   $TEMPLATE_NAME"
  say "  Directory:  $DIR"
  say "  Version:    $v"
  say "  Message:    ${MSG:-- $(git_title)}"
  say "  Activate:   false (INACTIVE)"
  say "  Git:        $(git_sha_short) ($(git_title))"
  say "Next: run  scripts/publish-coder-template.sh push --name $v"
}

# ----------------------------------------------------------------- push -----
cmd_push() {
  parse_args "$@"
  load_auth || die "auth failed"
  run_local_validation
  local v; v=$(derive_version "$NAME")
  local msg; msg=${MSG:-- $(git_title)}

  # Safety: if this exact version name already exists, refuse (avoid clobber).
  local exists
  exists=$(candidate_exists "$v")
  if [[ "$exists" != "ABSENT" ]]; then
    die "version '$v' already exists (status: $exists). Pick a new name or version."
  fi

  say ""
  say "---- Pushing INACTIVE candidate version '$v' ----"
  # -o json so we can confirm the version + that it is NOT active.
  coder templates push "$TEMPLATE_NAME" \
    --directory "$DIR" \
    --name "$v" \
    --message "$msg" \
    --activate=false \
    --yes 2>&1 | sed 's/^/  /'

  say ""
  say "---- Verifying candidate exists and is NOT Active ----"
  local line
  line=$(coder templates versions list "$TEMPLATE_NAME" 2>/dev/null | grep -E "^\s*$(printf '%s' "$v" | sed 's/[][\.*^$]/\\&/g') " || true)
  if [[ -z $line ]]; then
    die "version '$v' not found in versions list after push"
  fi
  printf '  %s\n' "$line"
  if printf '%s' "$line" | grep -q 'Active'; then
    die "version '$v' is marked Active — it should be INACTIVE (do not activate untested)"
  fi
  ok "candidate '$v' pushed and is INACTIVE"
  say ""
  say "Traceability:"
  say "  Git commit:       $(git_sha_short)  ($(git_title))"
  say "  Coder template:   $TEMPLATE_NAME@$v"
  say "Next: create a fresh disposable workspace from '$v' and validate, e.g.:"
  say "  scripts/publish-coder-template.sh create-ws --version $v --ws validation-$(git_sha_short)"
}

# -------------------------------------------------------------- create-ws ---
cmd_create_ws() {
  parse_args "$@"
  load_auth || die "auth failed"
  [[ -n $VERSION ]] || die "create-ws requires --version <candidate>"
  [[ -n $WS ]] || die "create-ws requires --ws <workspace-name>"
  local user
  user=$(coder whoami -o json 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)[0].get("username",""))' 2>/dev/null || true)
  [[ -n $user ]] || die "could not determine Coder username"

  say ""
  say "---- Creating disposable workspace '$user/$WS' from version '$VERSION' ----"
  say "(Using intended development profile parameters; secrets are Coder-managed, not sourced here.)"
  coder create "$user/$WS" \
    --template "$TEMPLATE_NAME" \
    --template-version "$VERSION" \
    --parameter bibliophilarr_ref=develop \
    --parameter workspace_mode=development \
    --parameter inference_provider=vllm \
    --parameter container_validation_enabled=true \
    --parameter media_mount_mode=read-only \
    --yes 2>&1 | sed 's/^/  /'
  say "Workspace creation requested. Poll:  coder list   /   coder workspace show $user/$WS"
}

# -------------------------------------------------------------- validate-ws -
cmd_validate_ws() {
  parse_args "$@"
  say ""
  say "==== Candidate workspace acceptance checklist (run from the new workspace) ===="
  say "Run these via:  coder ssh <user>/$WS  (or the workspace's ssh alias)"
  say "  [ ] workspace Started + Healthy (coder list)"
  say "  [ ] Coder agent Connected"
  say "  [ ] id  ->  coder / uid 1000"
  say "  [ ] /workspaces/Bibliophilarr exists + 'git -C ... rev-parse HEAD' == develop ref"
  say "  [ ] startup READY (bash -lc 'source /opt/workspace/bin/workspace-startup.sh 2>/dev/null || true; echo \$STARTUP_READY' or check journal)"
  say "  [ ] JetBrains: dashboard exposes Rider + WebStorm; launch metadata points at the candidate version"
  say "  [ ] project path = /workspaces/Bibliophilarr"
  say "  [ ] WORKSPACE_IMAGE_VERSION inside container matches the image tag used"
  say ""
  say "Promote ONLY after the above pass:"
  say "  scripts/publish-coder-template.sh promote --version <candidate>"
}

# ---------------------------------------------------------------- promote ---
cmd_promote() {
  parse_args "$@"
  load_auth || die "auth failed"
  [[ -n $VERSION ]] || die "promote requires --version <candidate>"
  # Safety: only promote Succeeded (not Failed) versions.
  local st; st=$(candidate_exists "$VERSION")
  [[ "$st" == "ABSENT" ]] && die "version '$VERSION' does not exist"
  [[ "$st" == "Succeeded" ]] || die "version '$VERSION' status is '$st' (only 'Succeeded' versions may be promoted)"

  say ""
  say "---- Promoting validated version '$VERSION' to Active ----"
  coder templates versions promote --template "$TEMPLATE_NAME" --template-version "$VERSION" 2>&1 | sed 's/^/  /'
  say ""
  say "---- Verifying '$VERSION' is now Active ----"
  local line
  line=$(coder templates versions list "$TEMPLATE_NAME" 2>&1 | grep -E "^\s*$(printf '%s' "$VERSION" | sed 's/[][\.*^$]/\\&/g') " || true)
  printf '  %s\n' "${line:-<version line not found>}"
  if printf '%s' "$line" | grep -q 'Active'; then
    ok "version '$VERSION' is now Active"
    say "  Git commit:       $(git_sha_short)"
    say "  Active template:  $TEMPLATE_NAME@$VERSION"
  else
    die "promotion did not mark '$VERSION' as Active"
  fi
}

# ----------------------------------------------------------------- cleanup --
cmd_cleanup() {
  parse_args "$@"
  load_auth || die "auth failed"
  [[ -n $WS ]] || die "cleanup requires --ws <workspace-name>"
  local user
  user=$(coder whoami -o json 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)[0].get("username",""))' 2>/dev/null || true)
  [[ -n $user ]] || die "could not determine Coder username"
  say ""
  say "---- Deleting disposable workspace '$user/$WS' ----"
  coder delete "$user/$WS" --force 2>&1 | sed 's/^/  /'
  ok "disposable workspace '$WS' deleted"
}

# --------------------------------------------------------------- dispatcher --
main() {
  local cmd="${1:-status}"; shift || true
  case "$cmd" in
    push)        cmd_push "$@" ;;
    plan)        cmd_plan "$@" ;;
    create-ws)   cmd_create_ws "$@" ;;
    validate-ws) cmd_validate_ws "$@" ;;
    promote)     cmd_promote "$@" ;;
    cleanup)     cmd_cleanup "$@" ;;
    status)      cmd_status "$@" ;;
    -h|--help|help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown subcommand '$cmd' (try: push|create-ws|validate-ws|promote|cleanup|status)"
      ;;
  esac
}

main "$@"
