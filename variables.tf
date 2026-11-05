variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "dockge_version" {
  type        = string
  default     = "1.5.0"
  nullable    = false
  description = "Tag of the Dockge image, such as \"1.5.0\". Change image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.dockge_version))
    error_message = "dockge_version must be an image tag, such as \"1.5.0\"."
  }
}

variable "image_digest" {
  type        = string
  default     = "sha256:335c6368b880ecc203236ed89e6e5232e0d6578e8ef5920e4a502390451502bf"
  nullable    = false
  description = "Digest of the image for dockge_version, such as \"sha256:335c...\". Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "image_repository" {
  type        = string
  default     = "docker.io/louislam/dockge"
  nullable    = false
  description = "Where to pull Dockge's image from, without a tag. Upstream publishes it on Docker Hub only."

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+$", var.image_repository))
    error_message = "image_repository must be a registry and path without a tag, such as \"docker.io/louislam/dockge\"."
  }
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address Dockge listens on. The default keeps it on the host for a reverse proxy in front; \"0.0.0.0\" listens on every address."

  validation {
    condition     = can(cidrhost("${var.listen_address}/${strcontains(var.listen_address, ":") ? 128 : 32}", 0))
    error_message = "listen_address must be an IPv4 or IPv6 address, such as \"127.0.0.1\"."
  }
}

variable "port" {
  type        = number
  default     = 5001
  description = "Port Dockge listens on."

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number from 1 to 65535."
  }
}

variable "stacks_dir" {
  type        = string
  default     = "/opt/stacks"
  nullable    = false
  description = "Directory holding a folder per stack, each with its compose.yaml. Dockge sees it at the same path."

  validation {
    condition     = can(regex("^/[A-Za-z0-9._/-]*[A-Za-z0-9._-]$", var.stacks_dir)) && !contains(["/", "/etc", "/usr", "/var", "/root", "/home"], var.stacks_dir)
    error_message = "stacks_dir must be an absolute path to a directory of its own, such as \"/opt/stacks\", with no trailing slash."
  }
}
