# =============================================================================
# Corporate Terraform Variables Template
# Project: Eurotax Integration Platform
# Environment: Development
# =============================================================================

# --- Hetzner Cloud ---
hcloud_token    = ""
server_name     = ""
server_type     = ""
server_location = ""
server_image    = ""

# --- SSH ---
ssh_key_name       = ""
ssh_public_key_path = ""

# --- Firewall ---
firewall_name = ""
allowed_ports = []

# --- Database (PostgreSQL) ---
postgres_version = ""
db_name_mock     = ""
db_user_mock     = ""
db_password_mock = ""
db_name_api      = ""
db_user_api      = ""
db_password_api  = ""

# --- Service: eurotax-mock ---
mock_port     = ""
mock_version  = ""
mock_repo_url = ""

# --- Service: eurotax-api ---
api_port     = ""
api_version  = ""
api_repo_url = ""

# --- Service: eurotax-ui ---
ui_port     = ""
ui_version  = ""
ui_repo_url = ""

# --- Docker Network ---
docker_network_subnet = ""
