output "service" {
  description = "The systemd service that runs Dockge on each host."
  value       = "dockge.service"
}

output "image" {
  description = "The Dockge image the hosts run."
  value       = local.image
}

output "url" {
  description = "Where Dockge answers on each host itself, such as \"http://127.0.0.1:5001\". Point a reverse proxy here."
  value       = local.local_url
}

output "stacks_dir" {
  description = "Directory on each host holding the stacks. Back it up, with /var/lib/dockge."
  value       = var.stacks_dir
}
