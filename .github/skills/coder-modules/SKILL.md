---
name: coder-modules
description: 'Create and update Coder Registry modules with scaffolding, variable management, script organization, Terraform testing, and version bumping. Use when building reusable tools, integrations, or runtime configurations; adding parameters or outputs; consuming other modules; organizing shell scripts; writing .tftest.hcl or TypeScript tests; or validating module structure.'
argument-hint: 'Describe the tool or functionality the module provides (e.g., "VSCode extension launcher" or "PostgreSQL database setup") and the target audience (template developers, end users, etc.)'
user-invocable: true
---

# Coder Modules Workflow

Create production-ready Coder Registry modules — reusable Terraform components that templates consume via `module` blocks to provision tools, integrations, environments, and runtime configuration.

## When to Use

- Creating a new reusable module from scratch (IDE, database, build tool, dev environment setup)
- Updating an existing module with new features (variables, outputs, scripts)
- Refactoring inline module logic from templates into a shareable module
- Organizing scripts (choosing between root `run.sh`, `scripts/` directory, or inline)
- Adding or updating Terraform tests (.tftest.hcl or main.test.ts)
- Managing versions and backward compatibility
- Consuming other registry modules within a module
- Validating module structure and dependencies

## Before You Start Checklist

**1. Understand the Request**
- What tool, integration, or functionality is the module providing? (IDE, database, build tool, runtime, dev service)
- What are the key installation steps, CLI flags, config files, and environment variables?
- Who will consume this module? (template developers, or will templates pass user choices into it?)
- What Coder resources does it need? (`coder_script`, `coder_app`, `coder_env`, `coder_metadata`, etc.)

**2. Research Existing Modules**
- Search [registry.coder.com/modules](https://registry.coder.com/modules) for similar modules
- Read their `main.tf` to understand patterns, variable conventions, script organization, and how they solve similar problems
- Look for modules that consume other modules (e.g., IDE wrappers) to see the pattern
- Check for deprecated or superseded modules to avoid duplicating outdated functionality

**3. Check Provider Documentation**
- **Coder provider**: [registry.terraform.io/providers/coder/coder/latest/docs](https://registry.terraform.io/providers/coder/coder/latest/docs)
- **Coder resources** used: `coder_app`, `coder_script`, `coder_env`, `coder_metadata`
- **Coder data sources**: `coder_parameter`, `coder_workspace`, `coder_workspace_owner`
- Verify resources and attributes exist in the provider version you're targeting
- Check changelogs for version constraints

**4. Clarify Before Building**
- What variables should the module expose to templates? (agent_id is always required)
- Will the module present parameters directly to workspace users, or will templates pass values?
- Are there conflicting options that should be validated? (e.g., "can't use both option_a and option_b")
- Is there a namespace for contribution? Never assume; always confirm with the user
- Should scripts be in a root `run.sh`, `scripts/` directory, or inline? Decide based on complexity

**5. Plan the Structure**
- List Coder resources (apps, scripts, env vars, metadata)
- List variables to expose (required and optional with sensible defaults)
- Decide on script organization (see Key Patterns below)
- Plan test coverage (.tftest.hcl for plan/apply, main.test.ts for complex logic)
- Document runtime prerequisites (tools, images, services that must exist before script runs)

## Implementation Steps

### For New Modules

**Step 1: Scaffold the Module**

If the repository has a scaffolding script:
```bash
./scripts/new_module.sh namespace/module-name
```

Creates:
- `registry/<namespace>/modules/<module-name>/main.tf`
- `registry/<namespace>/modules/<module-name>/README.md`
- `registry/<namespace>/modules/<module-name>/<module-name>.tftest.hcl`
- `registry/<namespace>/modules/<module-name>/run.sh`
- `registry/<namespace>/README.md` (if namespace is new)

Use lowercase alphanumeric names with hyphens (e.g., `acme/nodejs-runtime`). Underscores not allowed.

**Step 2: Define Variables**

Use `variable` blocks for module inputs. Naming rules:
- MUST be `snake_case` (no hyphens; Terraform validation rejects them)
- Required variables: no default (e.g., `agent_id`)
- Optional variables: provide sensible defaults for backward compatibility
- Common variable: `order` (number, default `null`, controls UI sort position)

```hcl
variable "agent_id" {
  description = "The Coder agent to attach scripts/apps to"
  type        = string
}

variable "port" {
  description = "Port to run the tool on"
  type        = number
  default     = 3000
}
```

Use `locals {}` for computed values: URL assembly, base64 encoding, script content via `file()`, config assembly.

**Step 3: Organize Scripts**

Choose one pattern based on complexity:

**Pattern A: Root `run.sh` + `templatefile()` (simple modules)**
- Single `run.sh` at module root
- Use `templatefile()` to inject Terraform variables
- Use `$${VAR}` (double dollar) in shell for escaping
- Examples: code-server, vscode-web, git-clone, dotfiles, filebrowser

```hcl
resource "coder_script" "my_tool" {
  agent_id     = var.agent_id
  display_name = "My Tool"
  icon         = "/icon/my-tool.svg"
  script = templatefile("${path.module}/run.sh", {
    PORT : var.port,
  })
  run_on_start = true
}
```

**Pattern B: `scripts/` directory + `file()` (complex modules)**
- Separate `scripts/install.sh` and `scripts/start.sh`
- Load via `file()` into `locals`, no Terraform interpolation
- Use when scripts don't need variable injection, or for config templates via `templates/` directory
- Examples: claude-code, copilot, cursor-cli

```hcl
locals {
  install_script = file("${path.module}/scripts/install.sh")
  start_script   = file("${path.module}/scripts/start.sh")
}

resource "coder_script" "setup" {
  agent_id = var.agent_id
  script   = local.install_script
  run_on_start = true
}
```

**Pattern C: Inline heredoc (minimal modules)**
- Trivial logic embedded directly in `coder_script` resource
- Examples: cursor, zed
- Only use when script is a few lines

Keep scripts organized:
- Script errors should handle gracefully: `|| echo "Warning..."` for non-fatal failures
- If sourcing external files (`$HOME/.bashrc`, `/etc/bashrc`, `/etc/os-release`), source BEFORE `set -u`
- Modules using `scripts/` directory can have `testdata/` with mock scripts for testing

**Step 4: Expose Outputs**

Define outputs for templates to consume:

```hcl
output "url" {
  description = "URL to access the tool"
  value       = try(coder_app.my_tool[0].url, "")
}

output "port" {
  description = "Port the tool is running on"
  value       = var.port
}
```

**Step 5: Write Tests**

Every module MUST have Terraform tests. See Key Patterns below for examples.

### For Updating Existing Modules

1. Read the entire `main.tf` to understand current resources, variables, and outputs
2. Identify the change (new variable, new output, script fix, etc.)
3. Apply changes following key patterns
4. Update tests if inputs or outputs changed
5. Run test suite to verify no regressions

## Key Patterns

**Provider Versions**: Only raise minimum `coder` provider version when the module uses a resource/attribute introduced in that version. Check the provider changelog.

**Variable Conventions**:
- `agent_id` (string, required, no default) — always present for modules that attach resources to agents
- `order` (number, default `null`) — controls UI position in workspace agent bar
- New variables must have sensible defaults to maintain backward compatibility
- Use validation blocks for constraints: `validation {}` with `min`/`max`/`regex`/`error`

**Module Consumption**: Modules can consume other registry modules:
```hcl
module "base" {
  source   = "registry.coder.com/namespace/base-ide/coder"
  version  = "1.0.0"
  agent_id = var.agent_id
}
```
Before consuming, read the module's `main.tf` and `README.md` to understand inputs, outputs, prerequisites, and runtime requirements. Pass only arguments you've confirmed exist.

**Coder Resources**:
- `coder_script`: Install/setup logic; runs on workspace start (use `run_on_start = true`)
- `coder_app`: Expose a running service with a clickable URL in the agent bar
- `coder_env`: Set environment variables in the agent
- `coder_metadata`: Display workspace stats and resource info in the dashboard

**Conditional Resources**: Use `count = var.enable_feature ? 1 : 0` to optionally include resources based on variables.

## README.md

Required YAML frontmatter:
```yaml
---
display_name: My Tool
description: Short description of what this module does and who should use it
icon: ../../../../.icons/my-tool.svg
verified: false
tags: [helper, ide]
---
```

Content rules:
- Single H1 matching `display_name`, directly below frontmatter
- Increment header levels by one (h1 → h2 → h3, not h1 → h3)
- Usage snippet with registry source and pinned version
- Code fences labeled `tf` (not `hcl`)
- Relative icon paths for README (`../../../../.icons/`)
- **Do NOT list variables, parameters, or outputs** — registry auto-generates these from Terraform
- Describe what the module does and how to use it in prose
- Usage examples are encouraged
- Use [GFM alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts): `> [!NOTE]`, `> [!WARNING]`, etc.

Example snippet:
```tf
module "my_tool" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/namespace/my-tool/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
}
```

## Icon Management

Modules reference icons in two places with different path systems:

**README frontmatter `icon:`** — Relative path to repo's `.icons/` directory (e.g., `../../../../.icons/my-tool.svg`)
- Displayed on registry website
- Same as templates

**`coder_script` / `coder_app` `icon =`** — Absolute `/icon/<name>.svg` path served by Coder deployment
- Served from `site/static/icon/` in the `coder/coder` repo
- Displayed in workspace agent bar

Workflow:
1. Check what exists in `.icons/` (README path) and similar modules (for `/icon/` paths)
2. Use existing icons when they fit
3. Reference the correct path even if the file doesn't exist yet; source the official SVG from the tool's branding page
4. Don't substitute generic icons; if the tool has its own brand, use the correct name

## Testing

### .tftest.hcl (Required)

Every module must have Terraform tests. Use `command = plan` for most tests:

```hcl
run "plan_with_defaults" {
  command = plan

  variables {
    agent_id = "test-agent-id"
  }

  assert {
    condition     = var.agent_id == "test-agent-id"
    error_message = "agent_id should be set"
  }
}

run "custom_port" {
  command = plan

  variables {
    agent_id = "test-agent-id"
    port     = 8080
  }

  assert {
    condition     = resource.coder_app.my_tool.url == "http://localhost:8080"
    error_message = "App URL should use configured port"
  }
}
```

Advanced patterns:
- `override_data` to mock data sources like `coder_workspace` and `coder_workspace_owner`
- `command = apply` when testing outputs or computed values
- `expect_failures` to test validation rules
- String assertions: `regexall()`, `startswith()`, `endswith()`
- Assert on resource attributes: `coder_env`, `coder_script`, `coder_app`

```hcl
run "validation_rejects_conflict" {
  command = plan

  variables {
    agent_id       = "test"
    option_a       = true
    option_b       = true
  }

  expect_failures = [
    var.option_a,
  ]
}
```

### main.test.ts (Optional)

For complex testing (Docker containers, script execution, HTTP mocking). Use test helpers from `~test`:

```typescript
import { describe, expect, it } from "bun:test";
import {
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
  findResourceInstance,
} from "~test";

describe("my-tool", () => {
  it("should init successfully", async () => {
    await runTerraformInit(import.meta.dir);
  });

  testRequiredVariables(import.meta.dir, {
    agent_id: "test-agent",
  });

  it("should apply with defaults", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "test-agent",
    });
    const app = findResourceInstance(state, "coder_app");
    expect(app.slug).toBe("my-tool");
  });
});
```

## Version Management

Bump version after changes using:
```bash
.github/scripts/version-bump.sh patch|minor|major
```

- `patch`: bugfixes
- `minor`: new features, new variables with defaults
- `major`: breaking changes (removed variables, changed defaults, new required variables)

The script auto-updates version references in README usage examples.

## Validation Checklist

Run these before finalizing:

1. **Tests pass**: `bun run check:terraform` and `bun run check:typescript` (or `bun check` for all)
2. **Formatting**: `bun run fmt`
3. **ShellCheck**: `bun run check:shellcheck` — scripts must source external files BEFORE `set -u`
4. **Backward compatibility**: New variables have sensible defaults; breaking changes are documented
5. **Error handling**: Shell scripts use `|| echo "Warning..."` for non-fatal failures
6. **No hardcoded values**: All configurable options are variables
7. **Relative paths**: Assets/icons use relative paths; external links OK
8. **Icon paths**: README uses `../../../../.icons/`; `coder_script`/`coder_app` uses `/icon/`
9. **README quality**: Describes functionality; no variable/output listings; includes usage example

## Commands

| Task             | Command                                               | Scope      |
| ---------------- | ----------------------------------------------------- | ---------- |
| Format all       | `bun run fmt`                                         | Repo       |
| Terraform tests  | `bun run check:terraform`                             | Repo       |
| TypeScript tests | `bun run check:typescript`                            | Repo       |
| Single TF test   | `terraform init -upgrade && terraform test -verbose`  | Module dir |
| Single TS test   | `bun test main.test.ts`                               | Module dir |
| Validate         | `./scripts/terraform_validate.sh`                     | Repo       |
| ShellCheck       | `bun run check:shellcheck`                            | Repo       |
| Version bump     | `.github/scripts/version-bump.sh patch\|minor\|major` | Repo       |

## References

- [Coder Documentation](https://coder.com/docs)
- [Coder Provider Docs](https://registry.terraform.io/providers/coder/coder/latest/docs)
- [Coder Registry](https://registry.coder.com)
- [Terraform Testing](https://developer.hashicorp.com/terraform/language/tests)

## Example Invocations

```
/coder-modules Python 3.11 runtime with pip package manager
/coder-modules Update module to add custom port parameter
/coder-modules Code-server IDE launcher for templates
/coder-modules Validate PostgreSQL database module tests
```
