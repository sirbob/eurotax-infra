output "server_ip" {
  description = "Public IP address of the Eurotax server"
  value       = hcloud_server.main.ipv4_address
}

output "server_status" {
  description = "Server status"
  value       = hcloud_server.main.status
}
