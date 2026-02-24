---
name: terraform-devops
description: >
  Comprehensive Terraform DevOps skill for provisioning cloud infrastructure.
  Covers CLI workflow, project structure, Hetzner Cloud provider, cloud-init,
  Docker installation, multi-stage Docker builds, and best practices for
  infrastructure-as-code projects.
---

# Terraform DevOps Skill

## CLI Workflow

Always follow this strict sequence when working with Terraform:

```
init  -->  validate  -->  plan  -->  apply  -->  output
```

### 1. Initialize

```bash
terraform init
```

- Downloads provider plugins and initializes the backend.
- Must be re-run after changing providers, modules, or backend configuration.
- Creates `.terraform/` directory and `.terraform.lock.hcl` lock file.

### 2. Format (optional but recommended)

```bash
terraform fmt -check -recursive
terraform fmt -recursive        # auto-fix
```

- Enforces canonical HCL style across all `.tf` files.
- Use `-check` in CI to fail on unformatted files.

### 3. Validate

```bash
terraform validate
```

- Checks configuration syntax and internal consistency (no API calls).
- Run after `init` so providers are available for type-checking.

### 4. Plan

```bash
terraform plan -out=tfplan
terraform plan -var-file=terraform.tfvars -out=tfplan
```

- Produces an execution plan showing what will be created, changed, or destroyed.
- Always save the plan to a file (`-out=tfplan`) for deterministic applies.

### 5. Apply

```bash
terraform apply tfplan                  # from saved plan (no prompt)
terraform apply -auto-approve           # skip prompt (demo/CI only)
```

- Executes the saved plan. If no plan file is given, Terraform plans and prompts.
- Use `-auto-approve` only in non-production or demo contexts.

### 6. Output

```bash
terraform output                        # all outputs
terraform output -json                  # JSON format for scripting
terraform output server_ip              # single value
terraform output -raw server_ip         # raw value (no quotes)
```

- Reads values from the current state file.
- Use `-raw` when piping output to other commands.

### 7. Destroy

```bash
terraform plan -destroy -out=tfplan     # preview destruction
terraform destroy -auto-approve         # tear down everything
```

---

## Project Structure

```
project-root/
  providers.tf        # terraform block, required_providers, provider configs
  variables.tf        # all input variable declarations
  main.tf             # resource definitions (servers, networks, firewalls)
  outputs.tf          # output value declarations
  terraform.tfvars    # actual variable values (may contain secrets)
  cloud-init.yaml.tftpl  # cloud-init template (rendered via templatefile)
  .terraform.lock.hcl # dependency lock file (commit to VCS)
  .gitignore          # exclude state, plans, secrets
```

### File Responsibilities

| File | Purpose |
|---|---|
| `providers.tf` | `terraform {}` block with `required_providers`, provider configuration blocks |
| `variables.tf` | All `variable` blocks with type, description, default, validation, sensitive |
| `main.tf` | All `resource` and `data` blocks defining infrastructure |
| `outputs.tf` | All `output` blocks exposing values from the state |
| `terraform.tfvars` | Concrete values for variables; auto-loaded by Terraform |
| `*.auto.tfvars` | Additional variable files, also auto-loaded |
| `cloud-init.yaml.tftpl` | Cloud-init template processed by `templatefile()` |

---

## Provider Configuration

### Hetzner Cloud Provider

```hcl
# providers.tf
terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
```

### Hetzner Server Resource

```hcl
# main.tf
resource "hcloud_server" "app" {
  name        = var.server_name
  server_type = var.server_type     # e.g. "cx32"
  image       = var.server_image    # e.g. "ubuntu-24.04"
  location    = var.server_location # e.g. "fsn1"
  ssh_keys    = [data.hcloud_ssh_key.default.id]
  user_data   = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    docker_compose_version = var.docker_compose_version
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

### Data Sources

```hcl
data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

data "hcloud_ssh_keys" "all" {}
```

---

## Variable Types, Validation, and Sensitive Marking

### Primitive Types

```hcl
variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "server_type" {
  type        = string
  description = "Hetzner server type"
  default     = "cx32"
}

variable "enable_backups" {
  type        = bool
  description = "Enable automated backups"
  default     = false
}
```

### Complex Types

```hcl
variable "labels" {
  type        = map(string)
  description = "Labels to apply to resources"
  default     = {}
}

variable "ssh_key_names" {
  type        = list(string)
  description = "List of SSH key names to attach"
}

variable "services" {
  type = list(object({
    name = string
    port = number
    path = string
  }))
  description = "List of service definitions"
}
```

### Validation Blocks

```hcl
variable "server_type" {
  type        = string
  description = "Hetzner server type"

  validation {
    condition     = contains(["cx22", "cx32", "cx42"], var.server_type)
    error_message = "server_type must be one of: cx22, cx32, cx42."
  }
}

variable "server_location" {
  type        = string
  description = "Hetzner datacenter location"

  validation {
    condition     = can(regex("^(fsn1|nbg1|hel1|ash|hil)$", var.server_location))
    error_message = "server_location must be a valid Hetzner location (fsn1, nbg1, hel1, ash, hil)."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "demo"

  validation {
    condition     = contains(["dev", "staging", "demo", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, demo, prod."
  }
}

variable "server_name" {
  type        = string
  description = "Server hostname (RFC 1123)"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.server_name))
    error_message = "server_name must be a valid hostname (lowercase alphanumeric, hyphens, max 63 chars)."
  }
}
```

### Sensitive Variables

```hcl
variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL password"
}

output "server_ip" {
  value       = hcloud_server.app.ipv4_address
  description = "Public IPv4 address of the server"
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

### terraform.tfvars Example

```hcl
# terraform.tfvars - actual values (DO NOT commit if it contains secrets)
hcloud_token    = "REDACTED"
server_name     = "eurotax-demo"
server_type     = "cx32"
server_image    = "ubuntu-24.04"
server_location = "fsn1"
ssh_key_name    = "default"
environment     = "demo"
db_password     = "REDACTED"
```

---

## Cloud-Init with templatefile()

### Template File (cloud-init.yaml.tftpl)

```yaml
#cloud-config

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - unzip
  - jq

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }

runcmd:
  # Install Docker using official convenience script
  - curl -fsSL https://get.docker.com | sh
  # Enable and start Docker
  - systemctl enable docker
  - systemctl start docker
  # Install Docker Compose plugin (v2)
  - mkdir -p /usr/local/lib/docker/cli-plugins
  - curl -fsSL "https://github.com/docker/compose/releases/download/v${docker_compose_version}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
  - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  # Verify installation
  - docker --version
  - docker compose version
  # Create app directory
  - mkdir -p /opt/app
```

### Using templatefile() in Resources

```hcl
resource "hcloud_server" "app" {
  # ... other arguments ...

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    docker_compose_version = var.docker_compose_version
  })
}
```

### templatefile() Tips

- Template files should use `.tftpl` extension by convention.
- Variables are interpolated with `${variable_name}` syntax.
- Use `%{ for item in list }...%{ endfor }` for iteration.
- Use `%{ if condition }...%{ endif }` for conditionals.
- Trailing `~` trims whitespace: `%{ endfor ~}`.

---

## State Management (Local)

For demo purposes, local state is acceptable:

```hcl
# providers.tf - local backend is the default, no explicit config needed
terraform {
  # State is stored in ./terraform.tfstate by default
  # For team/production use, configure a remote backend instead
}
```

### Local State Files

- `terraform.tfstate` - current state (contains secrets in plaintext).
- `terraform.tfstate.backup` - previous state backup.
- NEVER commit state files to version control.

### State Commands

```bash
terraform state list                    # list all resources in state
terraform state show hcloud_server.app  # inspect one resource
terraform state pull                    # dump full state as JSON
```

---

## .gitignore Patterns for Terraform

```gitignore
# Terraform state (contains secrets)
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Terraform variable files containing secrets
terraform.tfvars
*.auto.tfvars

# Exclude override files (used for local overrides)
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Terraform providers directory (downloaded by init)
.terraform/

# Saved plan files
*.tfplan
tfplan

# .env files
.env
.env.*

# OS files
.DS_Store
```

**Always commit:**
- `.terraform.lock.hcl` (dependency lock file - ensures reproducible builds)
- All `.tf` files

**Provide a template:**
- `terraform.tfvars.example` with placeholder values (no real secrets)

---

## Docker Installation via Cloud-Init YAML

The cloud-init template above installs Docker using the official convenience script. Key points:

1. **Package prerequisites** are installed first (`curl`, `ca-certificates`, `gnupg`).
2. **Docker Engine** is installed via `https://get.docker.com` script.
3. **Docker Compose v2** is installed as a CLI plugin (not standalone binary).
4. **Log rotation** is configured via `/etc/docker/daemon.json` to prevent disk fill.
5. **App directory** (`/opt/app`) is created for deployment artifacts.

### Verifying Docker Post-Provisioning

```bash
ssh root@$(terraform output -raw server_ip) "docker --version && docker compose version"
```

---

## Multi-Stage Docker Build Patterns

### Java (Maven) - Spring Boot Application

```dockerfile
# ---- Build Stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Cache dependencies first
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Build the application
COPY src ./src
RUN mvn package -DskipTests -B

# ---- Runtime Stage ----
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app

# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=build /app/target/*.jar app.jar

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### PHP (Composer + Node) - Laravel Application

```dockerfile
# ---- Node Build Stage (frontend assets) ----
FROM node:22-alpine AS frontend
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY vite.config.js tailwind.config.js postcss.config.js ./
COPY resources ./resources
RUN npm run build

# ---- Composer Stage (PHP dependencies) ----
FROM composer:2 AS composer
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY . .
RUN composer dump-autoload --optimize --no-dev

# ---- Runtime Stage ----
FROM php:8.2-fpm-alpine AS runtime
WORKDIR /app

# Install PHP extensions
RUN apk add --no-cache \
    libpq-dev \
    oniguruma-dev \
    && docker-php-ext-install \
    pdo_pgsql \
    mbstring \
    opcache

# Copy application
COPY --from=composer /app /app
COPY --from=frontend /app/public/build /app/public/build

# Set permissions
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

USER www-data

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD php-fpm-healthcheck || exit 1

CMD ["php-fpm"]
```

### Multi-Stage Build Benefits

- **Small images**: Runtime stage uses slim/alpine base (no build tools).
- **Cached layers**: Dependency files (`pom.xml`, `package.json`, `composer.json`) are copied before source code, so dependencies are cached unless lock files change.
- **Security**: Non-root users, no compilers/build tools in production image.
- **Reproducibility**: Lock files ensure deterministic dependency resolution.

---

## Best Practices for Infrastructure Projects

### Code Organization

1. **One concern per file**: Separate providers, variables, resources, and outputs.
2. **Descriptive variable names**: Use `server_type` not `st`; `db_password` not `pw`.
3. **Always add `description`** to every variable and output.
4. **Use `type` constraints** on every variable.
5. **Add `validation` blocks** for variables with known constraints.

### Security

1. **Mark secrets `sensitive = true`** on both variables and outputs.
2. **Never commit `terraform.tfvars`** with real secrets; provide a `.example` template.
3. **Use environment variables** as an alternative: `TF_VAR_hcloud_token`.
4. **Restrict firewall rules** to only necessary ports and source IPs.
5. **Use non-root users** in Docker containers.

### Reliability

1. **Pin provider versions** with `~>` (pessimistic constraint): `version = "~> 1.45"`.
2. **Commit `.terraform.lock.hcl`** to ensure all team members use identical provider builds.
3. **Save plans to files** (`-out=tfplan`) for deterministic applies.
4. **Add `depends_on`** when implicit dependencies are not sufficient (e.g., server depending on subnet).
5. **Use `lifecycle` blocks** when needed:
   ```hcl
   lifecycle {
     create_before_destroy = true
     ignore_changes        = [ssh_keys]
   }
   ```

### CI/CD Integration

```bash
# Typical CI pipeline steps
terraform fmt -check -recursive         # style check
terraform init -backend=false            # init without backend (for validation only)
terraform validate                       # syntax and type check

# In deployment pipeline
terraform init                           # full init with backend
terraform plan -out=tfplan               # generate plan
terraform apply tfplan                   # apply saved plan
```

### Labeling and Tagging

```hcl
labels = {
  environment = var.environment
  project     = "eurotax"
  managed_by  = "terraform"
}
```

### Output Design

```hcl
output "server_ip" {
  value       = hcloud_server.app.ipv4_address
  description = "Public IPv4 address of the provisioned server"
}

output "ssh_command" {
  value       = "ssh root@${hcloud_server.app.ipv4_address}"
  description = "SSH command to connect to the server"
}

output "server_status" {
  value       = hcloud_server.app.status
  description = "Current status of the server"
}
```

### Useful Terraform Functions

| Function | Usage |
|---|---|
| `templatefile(path, vars)` | Render a template file with variables |
| `file(path)` | Read a file as a string |
| `jsonencode(value)` | Convert a value to JSON string |
| `contains(list, value)` | Check if a list contains a value |
| `can(expression)` | Test if an expression evaluates without error |
| `regex(pattern, string)` | Match a regex pattern against a string |
| `format(spec, values...)` | Printf-style string formatting |
| `join(separator, list)` | Join list elements with separator |
| `lookup(map, key, default)` | Look up a key in a map with a default |
| `coalesce(vals...)` | Return first non-null/non-empty value |
