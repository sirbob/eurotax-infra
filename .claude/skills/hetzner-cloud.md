---
name: hetzner-cloud
description: >
  Comprehensive reference for Hetzner Cloud infrastructure provisioning,
  covering the REST API, Terraform hcloud provider, CLI tooling, cloud-init,
  and best practices for server, network, firewall, and SSH key management.
---

# Hetzner Cloud Skill

## 1. Hetzner Cloud API

| Detail        | Value                                |
|---------------|--------------------------------------|
| Base URL      | `https://api.hetzner.cloud/v1/`      |
| Auth          | Bearer token in `Authorization` header |
| Rate limit    | 3600 requests / hour                 |
| Pagination    | `?page=1&per_page=25` (max 50)       |
| Response      | JSON, all resources wrapped in a key (e.g. `{ "servers": [...] }`) |

### Authentication

```bash
curl -H "Authorization: Bearer $HCLOUD_TOKEN" \
     https://api.hetzner.cloud/v1/servers
```

### Common Endpoints

| Method | Endpoint                       | Purpose                  |
|--------|--------------------------------|--------------------------|
| GET    | `/servers`                     | List all servers         |
| POST   | `/servers`                     | Create a server          |
| DELETE | `/servers/{id}`                | Delete a server          |
| GET    | `/ssh_keys`                    | List SSH keys            |
| POST   | `/ssh_keys`                    | Upload SSH key           |
| GET    | `/server_types`                | List server types        |
| GET    | `/locations`                   | List locations           |
| GET    | `/firewalls`                   | List firewalls           |
| POST   | `/firewalls`                   | Create a firewall        |

---

## 2. Server Types

### Shared vCPU (CX line -- Intel/AMD)

| Type   | vCPU | RAM   | Disk   | Approx. Price |
|--------|------|-------|--------|---------------|
| cx22   | 2    | 4 GB  | 40 GB  | ~EUR 3.79/mo  |
| cx32   | 4    | 8 GB  | 80 GB  | ~EUR 7.49/mo  |
| cx42   | 8    | 16 GB | 160 GB | ~EUR 14.99/mo |
| cx52   | 16   | 32 GB | 320 GB | ~EUR 29.99/mo |

### Dedicated AMD (CPX line)

| Type   | vCPU | RAM   | Disk   |
|--------|------|-------|--------|
| cpx11  | 2    | 2 GB  | 40 GB  |
| cpx21  | 3    | 4 GB  | 80 GB  |
| cpx31  | 4    | 8 GB  | 160 GB |
| cpx41  | 8    | 16 GB | 240 GB |
| cpx51  | 16   | 32 GB | 360 GB |

### ARM64 (CAX line)

| Type   | vCPU | RAM   | Disk   |
|--------|------|-------|--------|
| cax11  | 2    | 4 GB  | 40 GB  |
| cax21  | 4    | 8 GB  | 80 GB  |
| cax31  | 8    | 16 GB | 160 GB |
| cax41  | 16   | 32 GB | 320 GB |

> **Tip:** For this project use `cx32` (4 vCPU, 8 GB) -- enough for Docker Compose
> with 3 Java/PHP services + PostgreSQL.

---

## 3. Locations

| Name   | City          | Country | Network Zone |
|--------|---------------|---------|--------------|
| `fsn1` | Falkenstein   | DE      | eu-central   |
| `nbg1` | Nuremberg     | DE      | eu-central   |
| `hel1` | Helsinki      | FI      | eu-central   |
| `ash`  | Ashburn, VA   | US      | us-east      |
| `hil`  | Hillsboro, OR | US      | us-west      |
| `sin`  | Singapore     | SG      | ap-southeast |

> **Default for this project:** `fsn1` (lowest latency from Central Europe).

---

## 4. Terraform Provider

### Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

provider "hcloud" {
  token = var.hcloud_token
}
```

The token can also be set via the `HCLOUD_TOKEN` environment variable.

### Provider Arguments

| Argument        | Required | Description                                      |
|-----------------|----------|--------------------------------------------------|
| `token`         | Yes      | API token (or use `HCLOUD_TOKEN` env var)        |
| `endpoint`      | No       | Override API URL (default `https://api.hetzner.cloud/v1`) |
| `poll_interval` | No       | Action polling interval (default `500ms`)        |
| `poll_function` | No       | Polling type: `constant` or `exponential` (default) |

---

## 5. Terraform Resources

### 5.1 `hcloud_ssh_key`

Upload an SSH public key for server injection.

```hcl
resource "hcloud_ssh_key" "default" {
  name       = "default-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
```

**Arguments:**
- `name` (Required, string) -- Display name.
- `public_key` (Required, string) -- SSH public key content.
- `labels` (Optional, map) -- Key-value labels.

**Exported attributes:** `id`, `name`, `public_key`, `fingerprint`, `labels`.

---

### 5.2 `hcloud_firewall`

Define firewall rules and optionally apply them to servers or label selectors.

```hcl
resource "hcloud_firewall" "web" {
  name = "web-firewall"

  rule {
    description = "Allow SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow app ports"
    direction   = "in"
    protocol    = "tcp"
    port        = "8000-8090"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}
```

**Rule block arguments:**

| Argument          | Required | Description                                                  |
|-------------------|----------|--------------------------------------------------------------|
| `direction`       | Yes      | `in` or `out`                                                |
| `protocol`        | Yes      | `tcp`, `udp`, `icmp`, `gre`, `esp`                          |
| `port`            | Yes*     | Port or range (e.g. `"80"`, `"8000-8090"`, `"any"`). *Required for tcp/udp. |
| `source_ips`      | Yes*     | CIDRs for inbound rules. *Required when direction is `in`.  |
| `destination_ips` | Yes*     | CIDRs for outbound rules. *Required when direction is `out`.|
| `description`     | No       | Human-readable description of the rule.                      |

**`apply_to` block (optional):**
- `server` (int) -- Server ID. Mutually exclusive with `label_selector`.
- `label_selector` (string) -- Label selector expression. Mutually exclusive with `server`.

> **Alternative:** Use `firewall_ids` on `hcloud_server` or the standalone
> `hcloud_firewall_attachment` resource.

---

### 5.3 `hcloud_network` and `hcloud_network_subnet`

Private networking between servers.

```hcl
resource "hcloud_network" "main" {
  name     = "main-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "default" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}
```

**Network arguments:** `name` (Required), `ip_range` (Required), `labels` (Optional).

**Subnet arguments:**

| Argument       | Required | Description                                      |
|----------------|----------|--------------------------------------------------|
| `network_id`   | Yes      | Parent network ID.                               |
| `type`         | Yes      | `server`, `cloud`, or `vswitch`.                 |
| `network_zone` | Yes      | e.g. `eu-central`, `us-east`, `ap-southeast`.    |
| `ip_range`     | Yes      | CIDR within parent network range.                |
| `vswitch_id`   | No       | Required only if type is `vswitch`.              |

---

### 5.4 `hcloud_server`

Create and manage a cloud server.

```hcl
resource "hcloud_server" "app" {
  name         = "app-server"
  server_type  = "cx32"
  image        = "ubuntu-24.04"
  location     = "fsn1"
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.web.id]
  user_data    = templatefile("${path.module}/cloud-init.yml.tftpl", {
    docker_compose_b64 = base64encode(file("${path.module}/docker-compose.yml"))
  })

  labels = {
    env     = "demo"
    project = "eurotax"
  }

  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }

  depends_on = [hcloud_network_subnet.default]
}
```

**Key arguments:**

| Argument       | Required | Description                                                     |
|----------------|----------|-----------------------------------------------------------------|
| `name`         | Yes      | Hostname (RFC 1123 compliant, unique per project).              |
| `server_type`  | Yes      | e.g. `cx22`, `cx32`, `cpx31`, `cax21`.                         |
| `image`        | Yes      | OS image name or ID (e.g. `ubuntu-24.04`, `debian-12`).        |
| `location`     | No       | e.g. `fsn1`, `nbg1`. Mutually exclusive with `datacenter`.     |
| `datacenter`   | No       | e.g. `fsn1-dc14`. Mutually exclusive with `location`.          |
| `ssh_keys`     | No       | List of SSH key IDs or names. Immutable after creation.         |
| `firewall_ids` | No       | List of firewall IDs to attach.                                 |
| `user_data`    | No       | Cloud-init YAML (see section 6).                                |
| `labels`       | No       | Key-value map.                                                  |
| `keep_disk`    | No       | If `true`, allows server type downgrade later.                  |
| `backups`      | No       | Enable automatic backups.                                       |
| `network`      | No       | Block for private network attachment (repeatable).              |
| `public_net`   | No       | Block to configure IPv4/IPv6. Defaults to both enabled.        |
| `delete_protection`  | No | Enable delete protection (must match `rebuild_protection`).    |
| `rebuild_protection` | No | Enable rebuild protection (must match `delete_protection`).    |
| `shutdown_before_deletion` | No | Graceful shutdown before destroy.                        |

**Exported attributes:** `id`, `ipv4_address`, `ipv6_address`, `ipv6_network`,
`status`, `datacenter`, `location`, `backup_window`, `primary_disk_size`.

> **Important:** When attaching to a network inline, always add
> `depends_on = [hcloud_network_subnet.<name>]` to prevent race conditions
> between subnet and server creation.

---

## 6. Cloud-Init (`user_data`)

Cloud-init runs on first boot. Pass it via the `user_data` argument.

### Static YAML

```hcl
resource "hcloud_server" "app" {
  # ...
  user_data = file("${path.module}/cloud-init.yml")
}
```

### Dynamic with `templatefile()`

```hcl
resource "hcloud_server" "app" {
  # ...
  user_data = templatefile("${path.module}/cloud-init.yml.tftpl", {
    ssh_port       = 22
    app_domain     = "demo.example.com"
    compose_file   = base64encode(file("${path.module}/docker-compose.yml"))
  })
}
```

### Example `cloud-init.yml.tftpl`

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

runcmd:
  # Install Docker
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker

  # Install Docker Compose plugin
  - apt-get install -y docker-compose-plugin

  # Decode and deploy compose file
  - mkdir -p /opt/app
  - echo '${compose_file}' | base64 -d > /opt/app/docker-compose.yml

  # Start services
  - cd /opt/app && docker compose up -d

write_files:
  - path: /etc/ssh/sshd_config.d/custom.conf
    content: |
      Port ${ssh_port}
      PermitRootLogin prohibit-password
      PasswordAuthentication no
```

> **Note:** `user_data` changes force server replacement (destroy + recreate).
> Use `lifecycle { ignore_changes = [user_data] }` if you want to update
> config in-place via SSH instead.

---

## 7. CLI (`hcloud`)

### Installation

```bash
brew install hcloud          # macOS
# or
apt install hcloud-cli       # Debian/Ubuntu
```

### Configuration

```bash
hcloud context create devops-demo   # prompts for token
hcloud context use devops-demo
hcloud context list
```

### Common Commands

```bash
# Server operations
hcloud server list
hcloud server create --name app --type cx32 --image ubuntu-24.04 --location fsn1 --ssh-key default
hcloud server ssh app                          # SSH into server
hcloud server delete app

# SSH keys
hcloud ssh-key list
hcloud ssh-key create --name default --public-key-from-file ~/.ssh/id_rsa.pub

# Firewall
hcloud firewall list
hcloud firewall create --name web-fw
hcloud firewall add-rule web-fw --direction in --protocol tcp --port 22 --source-ips 0.0.0.0/0 --source-ips ::/0
hcloud firewall apply-to-resource web-fw --type server --server app

# Network
hcloud network list
hcloud network create --name main --ip-range 10.0.0.0/16

# Server types & images
hcloud server-type list
hcloud image list --type system

# Misc
hcloud datacenter list
hcloud location list
```

---

## 8. Complete Example -- Single Server with Docker Compose

This is the typical pattern for the devops-demo project.

```hcl
# --- variables.tf ---
variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "server_type" {
  type    = string
  default = "cx32"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

# --- main.tf ---
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

resource "hcloud_ssh_key" "default" {
  name       = "default"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_firewall" "app" {
  name = "app-firewall"

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "App ports"
    direction   = "in"
    protocol    = "tcp"
    port        = "8000-8090"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "app" {
  name         = "eurotax-demo"
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.app.id]

  user_data = templatefile("${path.module}/cloud-init.yml.tftpl", {
    compose_b64 = base64encode(file("${path.module}/files/docker-compose.yml"))
  })

  labels = {
    project = "eurotax"
    env     = "demo"
  }
}

# --- outputs.tf ---
output "server_ip" {
  value       = hcloud_server.app.ipv4_address
  description = "Public IPv4 address of the server"
}

output "server_status" {
  value = hcloud_server.app.status
}
```

---

## 9. Best Practices

### Security
- **Never commit API tokens.** Use `HCLOUD_TOKEN` env var or a `.tfvars` file
  excluded via `.gitignore`.
- **Restrict SSH source IPs** in firewall rules when possible (not `0.0.0.0/0`).
- **Disable password auth** via cloud-init (`PasswordAuthentication no`).
- **Use `delete_protection`** on production servers to prevent accidental deletion.

### Terraform
- **Pin provider version** with `~> 1.45` to avoid breaking changes.
- **Use `depends_on`** when attaching servers to networks inline -- subnets and
  servers otherwise race.
- **Mark `hcloud_token` as `sensitive = true`** to prevent it from appearing
  in plan output.
- **Use `lifecycle.ignore_changes = [ssh_keys]`** if SSH keys may be modified
  outside Terraform.
- **Use `keep_disk = true`** if you anticipate needing to downgrade server type.
- **Store state remotely** (S3/GCS backend) for team collaboration; local state
  is fine for single-operator demos.

### Cloud-Init
- **`user_data` changes force server recreation.** For iterative development,
  prefer SSH-based provisioning or `ignore_changes`.
- **Use `templatefile()`** for dynamic values; avoid string interpolation in
  raw YAML.
- **Base64-encode large files** (compose files, scripts) and decode in `runcmd`.
- **Test cloud-init locally** with `cloud-init schema --config-file cloud-init.yml`.

### Networking
- **Private networks** are free and add no latency within the same datacenter.
- **Network zones** must match the server location (e.g. `eu-central` for `fsn1`).
- **Use specific IPs** in the `network` block to have predictable addressing.

### Cost Optimization
- **Delete unused servers** -- billing is per-hour, even when stopped (for disk).
- **Use `cx22`** for light workloads; `cx32` for medium multi-service setups.
- **ARM (`cax`) servers** are cheaper for compatible workloads.
- **Snapshots** are billed at EUR 0.0119/GB/mo -- delete old ones.

---

## 10. Useful Data Sources

```hcl
# Look up existing SSH key by name
data "hcloud_ssh_key" "existing" {
  name = "default"
}

# Look up server type details
data "hcloud_server_type" "cx32" {
  name = "cx32"
}

# Look up image
data "hcloud_image" "ubuntu" {
  name              = "ubuntu-24.04"
  with_architecture = "x86"
}

# Look up location
data "hcloud_location" "fsn1" {
  name = "fsn1"
}

# Look up all servers with a label
data "hcloud_servers" "demo" {
  with_selector = "project=eurotax"
}
```

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `403 Forbidden` | Invalid or expired API token | Regenerate token in Hetzner Console |
| `409 Conflict: server name already used` | Duplicate name in project | Use unique names or import existing resource |
| `422 Unprocessable: cloud-init invalid` | Malformed YAML in `user_data` | Validate with `cloud-init schema` |
| Server created but cloud-init did not run | `user_data` passed after creation | Cloud-init only runs on first boot; recreate server |
| Network attachment fails randomly | Race condition with subnet | Add `depends_on` to link server to subnet resource |
| SSH timeout after creation | Firewall missing port 22 rule | Add SSH rule to firewall, verify `source_ips` |
| `rate limit exceeded` | Too many API calls | Increase `poll_interval` in provider config |
