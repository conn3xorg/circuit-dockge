locals {
  image  = "${var.image_repository}:${var.dockge_version}@${var.image_digest}"
  data   = "/var/lib/dockge"
  socket = "/run/podman/podman.sock"

  local_host = lookup({ "0.0.0.0" = "127.0.0.1", "::" = "[::1]" }, var.listen_address, strcontains(var.listen_address, ":") ? "[${var.listen_address}]" : var.listen_address)
  local_url  = "http://${local.local_host}:${var.port}"

  # Waits for a listener on the port, read from /proc so the host needs no ss.
  wait_port = "for _ in $(seq 900); do grep -qE ':${format("%04X", var.port)} [0-9A-F]+:[0-9A-F]{4} 0A ' /proc/net/tcp /proc/net/tcp6 2>/dev/null && exit 0; sleep 1; done; echo 'Nothing listened on port ${var.port} in 15 minutes. See journalctl -u dockge.' >&2; exit 1"
}

circuit "dockge" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # circuit-podman installs it too. It's needed here first for the socket,
  # which has to exist before Dockge's container can mount it.
  step "podman" {
    package {
      name = "podman"
    }
  }

  # Podman's Docker-compatible API. Dockge runs `docker compose` against it,
  # so every stack runs as a rootful Podman container.
  step "socket" {
    service {
      name    = "podman.socket"
      state   = "started"
      enabled = true
    }
  }

  # Newer Podman starts restart: unless-stopped containers at boot, as Docker
  # does, and its podman-restart.service filters on should-start-on-boot.
  # Older ones (Ubuntu 24.04's 4.9, Debian 13's 5.4) start only restart:
  # always containers, and compose files mostly say unless-stopped. Those
  # can't tell which containers someone stopped, so this starts them all.
  step "restart_unless_stopped" {
    file {
      path    = "/etc/systemd/system/podman-restart.service.d/50-conn3x-unless-stopped.conf"
      content = <<-EOT
        # Written by Conn3x. Changes here are overwritten on the next apply.
        [Service]
        ExecStart=/bin/sh -c 'grep -qs should-start-on-boot /usr/lib/systemd/system/podman-restart.service || exec podman start --all --filter restart-policy=unless-stopped'
      EOT
    }
  }

  # Starts containers with a restart policy at boot. Podman has no daemon to
  # do it, as Docker's does.
  step "restart_at_boot" {
    service {
      name    = "podman-restart.service"
      enabled = true
    }
  }

  # Dockge's own database and settings. It runs as root, so nobody else on
  # the host needs to get in.
  step "data" {
    directory {
      path  = local.data
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }

  # Every stack's compose.yaml and .env, which can hold secrets.
  step "stacks" {
    directory {
      path  = var.stacks_dir
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }
}

# Dockge runs from its official image as a Quadlet unit, on the host's
# network, with DOCKGE_HOSTNAME and DOCKGE_PORT deciding where it listens.
# The stacks directory is mounted at the same path inside, since compose
# resolves relative bind mounts there and Podman then reads them on the host.
# The API socket gives the container root on the host, which is what Dockge
# is for, so SELinux labelling is off for it alone.
module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_service.dockge__socket, conn3x_directory.dockge__data, conn3x_directory.dockge__stacks]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = {
    dockge = {
      image = local.image
      volumes = [
        "${local.socket}:/var/run/docker.sock",
        "${local.data}:/app/data",
        "${var.stacks_dir}:${var.stacks_dir}",
      ]
      environment = {
        DOCKGE_HOSTNAME   = var.listen_address
        DOCKGE_PORT       = tostring(var.port)
        DOCKGE_STACKS_DIR = var.stacks_dir
      }
      extra = ["Network=host", "SecurityLabelDisable=true"]
    }
  }
}

circuit "ready" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # On a first start Dockge pulls its image before it listens. The wait_for
  # below was already met before a restart, so a change that restarts the
  # container waits here.
  step "restarted" {
    depends_on = [module.podman]
    command {
      command  = local.wait_port
      triggers = sha256(jsonencode([local.image, var.listen_address, var.port, var.stacks_dir]))
    }
  }

  step "port" {
    wait_for {
      port    = var.port
      timeout = "15m"
    }
  }
}
