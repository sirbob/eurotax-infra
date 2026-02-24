#!/usr/bin/env bash
# Validates that all required tfvars values are non-empty.
# Usage: ./scripts/validate-tfvars.sh [path-to-tfvars]
# Exit 0 = all values populated, Exit 1 = missing values found.

set -euo pipefail

TFVARS_FILE="${1:-terraform.tfvars}"

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "FAIL: $TFVARS_FILE not found"
  exit 1
fi

ERRORS=0

check_var() {
  local var_name="$1"
  local value
  value=$(grep -E "^${var_name}\s*=" "$TFVARS_FILE" | sed 's/^[^=]*=\s*//' | sed 's/^"\(.*\)"$/\1/' | xargs)

  if [[ -z "$value" ]]; then
    echo "FAIL: $var_name is empty or missing"
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK: $var_name"
  fi
}

echo "Validating $TFVARS_FILE..."
echo ""

echo "--- Hetzner Cloud ---"
check_var "hcloud_token"
check_var "server_name"
check_var "server_type"
check_var "server_location"
check_var "server_image"

echo ""
echo "--- SSH ---"
check_var "ssh_key_name"
check_var "ssh_public_key_path"

echo ""
echo "--- Firewall ---"
check_var "firewall_name"

echo ""
echo "--- Database ---"
check_var "postgres_version"
check_var "db_name_mock"
check_var "db_user_mock"
check_var "db_password_mock"
check_var "db_name_api"
check_var "db_user_api"
check_var "db_password_api"

echo ""
echo "--- Services ---"
check_var "mock_port"
check_var "mock_version"
check_var "mock_repo_url"
check_var "api_port"
check_var "api_version"
check_var "api_repo_url"
check_var "ui_port"
check_var "ui_version"
check_var "ui_repo_url"

echo ""
echo "--- Network ---"
check_var "docker_network_subnet"

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "RESULT: FAIL — $ERRORS variable(s) missing or empty"
  exit 1
else
  echo "RESULT: PASS — all variables populated"
  exit 0
fi
