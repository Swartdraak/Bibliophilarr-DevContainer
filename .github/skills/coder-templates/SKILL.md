---
name: coder-templates
description: 'Create and update Coder Registry workspace templates with infrastructure provisioning, agent setup, and module consumption. Use when building Docker, AWS, GCP, Azure, or Kubernetes templates; adding parameters and presets; consuming registry modules; or validating template structure.'
argument-hint: 'Describe the template type (platform) and requirements (e.g., "Docker container with Node.js" or "AWS EC2 with persistent storage")'
user-invocable: true
---

# Coder Templates Workflow

Create production-ready Coder Registry workspace templates that provision infrastructure, configure agents, and expose workspace parameters to users.

## When to Use

- Creating a new workspace template from scratch (Docker, VM, Kubernetes, etc.)
- Updating an existing template with new features (parameters, modules, presets)
- Consuming registry modules for standard functionality
- Adding parameters, presets, or prebuilds (Premium)
- Validating template Terraform syntax and structure
- Generating templates for documentation or contribution to the public registry

## Before You Start Checklist

**1. Understand the Request**
- What platform? (Docker, AWS, GCP, Azure, Kubernetes, or hybrid)
- What compute type? (container, VM, pod, devcontainer)
- What is the intended use case? (general dev, data science, Go development, etc.)
- Should users be able to customize resources? (CPU, memory, disk, region, runtime versions)

**2. Research Existing Templates**
- Check `registry/` in your repository for similar templates
- Browse [Coder Registry](https://registry.coder.com) for community/partner examples
- Read the `main.tf` of a similar template to understand patterns
- Identify reusable modules under `registry/*/modules/` or registry.coder.com

**3. Check Provider Documentation**
- **Coder provider**: [registry.terraform.io/providers/coder/coder/latest/docs](https://registry.terraform.io/providers/coder/coder/latest/docs)
- **Infrastructure provider** (Docker, AWS, etc.): Version-specific docs via `https://registry.terraform.io/providers/ORG/NAME/latest/docs`
- Verify resources and attributes exist in the version you plan to target
- Check changelogs for version constraints

**4. Clarify Ambiguities**
- If platform, parameters, or namespace are unclear, ask the user before proceeding
- Never assume a namespace for contribution; always confirm with the user
- Confirm whether prebuilds or presets are desired (understand Premium licensing implications)

**5. Plan the Structure**
- List infrastructure resources to provision
- Define `coder_parameter` options users will see
- Identify registry modules to consume (vs. inline implementations)
- Determine if cloud-init, Dockerfile, or other helper files are needed
- Document any runtime prerequisites (tools, runtimes, services)

## Implementation Steps

### For New Templates

**Step 1: Scaffold the Template**

If the repository has a scaffolding script:
```bash
./scripts/new_template.sh namespace/template-name
```

This creates:
- `registry/<namespace>/templates/<template-name>/main.tf`
- `registry/<namespace>/templates/<template-name>/README.md`
- `registry/<namespace>/README.md` (if namespace is new)

Replace `namespace/template-name` with lowercase alphanumeric names and hyphens (e.g., `acme/nodejs-docker`).

**Step 2: Define Parameters**

Use `data "coder_parameter"` for user-facing options. Common parameters:
- **Cloud templates**: region, instance type, CPU, memory, disk size
- **Container templates**: base image, runtime version
- **All templates**: workspace name, owner, labels

Use `dynamic "option"` blocks with `for_each` to avoid hardcoding option lists. Reference helper modules like `coder/aws-region` for region selectors.

**Step 3: Consume Modules**

Before implementing functionality from scratch:
- Search `registry/*/modules/` in your repo or [registry.coder.com/modules](https://registry.coder.com/modules)
- Read the module's `README.md` and `main.tf` to understand inputs and outputs
- Verify the base image or infrastructure supports all prerequisites
- Use `source = "registry.coder.com/<namespace>/<module-name>"` for remote modules

**Step 4: Provision Infrastructure**

- Use `data.coder_workspace.me` and `data.coder_workspace_owner.me` for workspace metadata
- Include `data.coder_provisioner.me` only when you need provisioner OS/arch (Docker, Kubernetes); omit for fixed-OS VMs
- Use `locals {}` for computed values (scripts, URLs, environment variables)
- Label resources with `coder.owner` and `coder.workspace_id` tags for tracking
- Use `lifecycle { ignore_changes = all }` on persistent volumes to prevent data loss

**Step 5: Configure the Agent**

- Connect compute to agent via `coder_agent.main.init_script` and `CODER_AGENT_TOKEN`
- Define environment variables with `coder_env`
- Expose applications with `coder_app` blocks
- Add metadata with `coder_metadata` for dashboard stats

### For Updating Existing Templates

1. Read the entire `main.tf` to understand current resources, parameters, and module consumption
2. Identify the change (add parameter, add module, fix configuration)
3. Apply changes following the key patterns below
4. Note any structural deviations from standards (hardcoded values that should be parameters, missing metadata, etc.) and propose improvements

## Key Patterns

**Provider Versions**: Only set minimum version when the template uses a resource/attribute introduced in that version. Check changelogs.

**Computed Values**: Use `locals {}` for environment variables, scripts, URLs, and startup commands instead of hardcoding.

**Ephemeral Resources**: Use `count = data.coder_workspace.me.start_count` on resources that should not persist between stops.

**Module Prerequisites**: Verify base image includes required tools before consuming a module. Cloud-init issues only surface at runtime; they are not caught by `terraform validate`.

**Relative Paths in README**: Use `../../../../.icons/` for icon references; never use absolute paths.

**Conditional Parameters**: Use `count` to show/hide a parameter based on another parameter's value.

**Presets**: Bundle parameter combinations with `data "coder_workspace_preset"`. Users can select a preset to auto-fill multiple options at once.

```hcl
data "coder_workspace_preset" "standard" {
  name    = "Standard Dev Environment"
  default = true
  parameters = {
    "region"  = "us-east-1"
    "cpu"     = "4"
    "memory"  = "8"
  }
}
```

**Prebuilds (Premium Feature)**: Maintain a pool of pre-provisioned workspaces for a preset to reduce creation time. Requires Premium license.

## README Structure

Required frontmatter:
```yaml
---
display_name: Docker Containers
description: Provision Docker containers with persistent home volumes as Coder workspaces
icon: ../../../../.icons/docker.svg
verified: false
tags: [docker, container]
---
```

- Single H1 matching `display_name`
- **Prerequisites** section (infrastructure, credentials, provider setup)
- **Architecture** section (what resources are created, what persists)
- Opening paragraph describing the platform and capabilities specifically (not generically)
- Use [GFM alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts): `> [!NOTE]`, `> [!WARNING]`, etc.
- Do NOT list variables or parameters (the registry auto-generates that from Terraform)
- Code fences labeled `tf` (not `hcl`)

## Validation Checklist

Run these before finalizing:

1. **Terraform**: `cd registry/<namespace>/templates/<name>/ && terraform init && terraform validate`
2. **Formatting**: `bun run fmt` (from repo root) or `terraform fmt`
3. **Shell scripts**: `bun run check:shellcheck` — scripts must source external files BEFORE `set -u`
4. **Error handling**: Shell scripts use `|| echo "Warning..."` for non-fatal failures
5. **No hardcoded values**: All configurable options are parameters
6. **Relative paths**: Assets and icons use relative paths; external links are OK
7. **README quality**: Prerequisites and architecture described; no variable listings
8. **Resource labels**: Infrastructure tagged with `coder.owner` and `coder.workspace_id`
9. **Persistent storage**: Uses `lifecycle { ignore_changes = all }` where appropriate

## Premium Features

Templates can use Premium-only features (prebuilds, advanced scheduling). If you use these, note in your response that the Coder deployment must have a Premium license.

## Pushing the Template

After validation, push to your Coder deployment:

```bash
coder templates push \
  registry/ \
  -m "Brief description of changes" \
  -y \
  -d <namespace>/templates/<template-name>/
```

For new namespaces contributing to the public registry:
- Fill out the namespace README (`display_name`, `bio`, `status`, `github`)
- Replace the placeholder avatar in `.images/` (400x400px minimum)
- Verify all icon paths exist in the repo's `.icons/` directory

## References

- [Coder Documentation](https://coder.com/docs)
- [Coder Provider Docs](https://registry.terraform.io/providers/coder/coder/latest/docs)
- [Coder Registry](https://registry.coder.com)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)

## Example Invocations

```
/coder-templates Docker container with Python 3.11 and Jupyter
/coder-templates Update template to add region parameter
/coder-templates AWS EC2 for data science with GPU support and prebuilds
/coder-templates Validate Docker template main.tf
```
