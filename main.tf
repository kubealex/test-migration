# Test case for the updated libvirt modules
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Create a storage pool
module "test_pool" {
  source = "../terraform-libvirt-libvirt-resources/pool"

  pool_name = "test-pool"
  pool_path = "/var/lib/libvirt/images"
}

# Create a network
module "test_network" {
  source = "../terraform-libvirt-libvirt-resources/network"

  network_name       = "test-network"
  network_mode       = "nat"
  network_domain     = "test.local"
  network_cidr       = ["192.168.100.0/24"]
  network_autostart  = true
  network_dns_enabled = true
  network_dns_local   = true
  network_dhcp_enabled = true
  network_dhcp_range_start = "192.168.100.10"
  network_dhcp_range_end   = "192.168.100.100"

  # DNS entries for the test VM
  network_dns_entries = {
    "test-vm" = "192.168.100.50"
  }

  # Optional: Add a DNS SRV record
  network_dns_srv_records = [
    {
      service  = "http"
      protocol = "tcp"
      domain   = "test.local"
      target   = "test-vm.test.local"
      port     = 80
      priority = 10
      weight   = 100
    }
  ]

  network_routes = {
    # Optional: Add custom routes if needed
    # "10.0.0.0/24" = "192.168.100.1"
  }
}

# Create an instance
module "test_instance" {
  source = "../terraform-libvirt-libvirt-resources/instance"

  # Dependencies
  depends_on = [
    module.test_pool,
    module.test_network
  ]

  instance_count              = 1
  instance_hostname           = "test-vm"
  instance_domain             = "test.local"
  instance_autostart          = true
  instance_cpu                = 2
  instance_memory             = 2  # 2 GB
  instance_volume_size        = 10 # 10 GB
  instance_type               = "linux"
  instance_libvirt_pool       = module.test_pool.pool_name
  instance_uefi_enabled       = true
  instance_firmware           = "/usr/share/edk2/ovmf/OVMF_CODE.fd"

  # Use Ubuntu cloud image
  instance_cloud_image = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"

  # Cloud-init configuration
  instance_cloudinit_path = "${path.module}/cloud-init.cfg"

  instance_cloud_user = {
    username = "ubuntu"
    password = "ubuntu"
    sshkey   = file("~/.ssh/id_rsa.pub")  # Replace with your SSH public key path
  }

  # Network configuration
  instance_network_interfaces = [
    {
      interface_network     = module.test_network.network_name
      interface_mac_address = "52:54:00:ab:cd:01"
      interface_addresses   = ["192.168.100.50"]
      interface_hostname    = "test-vm"
    }
  ]

  # Optional: Add additional storage
  instance_additional_volume_size = 5  # 5 GB additional disk
}
