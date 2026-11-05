variable "port" {
  type    = number
  default = 2222
}

# Null takes the circuit's defaults. CI sets an older pair first, to test an
# upgrade.
variable "dockge_version" {
  type    = string
  default = null
}

variable "image_digest" {
  type    = string
  default = null
}

module "dockge" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  dockge_version = var.dockge_version
  image_digest   = var.image_digest
}
