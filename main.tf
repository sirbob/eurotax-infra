# =============================================================================
# Main Infrastructure - Eurotax Integration Platform
# =============================================================================

data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "hcloud_firewall" "default" {
  name = var.firewall_name

  dynamic "rule" {
    for_each = var.allowed_ports
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = rule.value
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

resource "hcloud_server" "main" {
  name         = var.server_name
  server_type  = var.server_type
  location     = var.server_location
  image        = var.server_image
  ssh_keys     = [data.hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.default.id]
  user_data    = file("cloud-init.yml")

  labels = {
    project     = "eurotax"
    environment = "dev"
  }
}
