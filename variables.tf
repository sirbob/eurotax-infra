# =============================================================================
# Hetzner Cloud Authentication
# =============================================================================

variable "hcloud_token" {
  description = "Hetzner Cloud API token for authentication"
  type        = string
  sensitive   = true
}

# =============================================================================
# Server Configuration
# =============================================================================

variable "server_name" {
  description = "Name of the Hetzner Cloud server instance"
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type (e.g., cx32 for 4 vCPU, 8GB RAM)"
  type        = string
}

variable "server_location" {
  description = "Hetzner Cloud datacenter location (e.g., fsn1, nbg1, hel1)"
  type        = string
}

variable "server_image" {
  description = "Operating system image for the server (e.g., ubuntu-24.04)"
  type        = string
}

# =============================================================================
# SSH Configuration
# =============================================================================

variable "ssh_key_name" {
  description = "Name of the SSH key resource in Hetzner Cloud"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Local filesystem path to the SSH public key file"
  type        = string
}

# =============================================================================
# Firewall Configuration
# =============================================================================

variable "firewall_name" {
  description = "Name of the Hetzner Cloud firewall resource"
  type        = string
}

variable "allowed_ports" {
  description = "List of TCP ports to allow through the firewall (e.g., 22, 80, 443)"
  type        = list(string)
}

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

variable "postgres_version" {
  description = "PostgreSQL Docker image version tag"
  type        = string
}

# =============================================================================
# Database - Mock Service
# =============================================================================

variable "db_name_mock" {
  description = "PostgreSQL database name for the eurotax-mock service"
  type        = string
}

variable "db_user_mock" {
  description = "PostgreSQL username for the eurotax-mock service"
  type        = string
}

variable "db_password_mock" {
  description = "PostgreSQL password for the eurotax-mock service"
  type        = string
  sensitive   = true
}

# =============================================================================
# Database - API Service
# =============================================================================

variable "db_name_api" {
  description = "PostgreSQL database name for the eurotax-api service"
  type        = string
}

variable "db_user_api" {
  description = "PostgreSQL username for the eurotax-api service"
  type        = string
}

variable "db_password_api" {
  description = "PostgreSQL password for the eurotax-api service"
  type        = string
  sensitive   = true
}

# =============================================================================
# Mock Service Configuration
# =============================================================================

variable "mock_port" {
  description = "Host port exposed by the eurotax-mock service"
  type        = string
}

variable "mock_version" {
  description = "Docker image version tag for the eurotax-mock service"
  type        = string
}

variable "mock_repo_url" {
  description = "Git repository URL for the eurotax-mock source code"
  type        = string
}

# =============================================================================
# API Service Configuration
# =============================================================================

variable "api_port" {
  description = "Host port exposed by the eurotax-api service"
  type        = string
}

variable "api_version" {
  description = "Docker image version tag for the eurotax-api service"
  type        = string
}

variable "api_repo_url" {
  description = "Git repository URL for the eurotax-api source code"
  type        = string
}

# =============================================================================
# UI Service Configuration
# =============================================================================

variable "ui_port" {
  description = "Host port exposed by the eurotax-ui service"
  type        = string
}

variable "ui_version" {
  description = "Docker image version tag for the eurotax-ui service"
  type        = string
}

variable "ui_repo_url" {
  description = "Git repository URL for the eurotax-ui source code"
  type        = string
}

# =============================================================================
# Docker Network Configuration
# =============================================================================

variable "docker_network_subnet" {
  description = "CIDR subnet for the Docker bridge network (e.g., 172.20.0.0/16)"
  type        = string
}
