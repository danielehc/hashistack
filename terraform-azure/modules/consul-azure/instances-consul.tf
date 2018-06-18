data "template_file" "init" {
  template = "${file("${path.module}/init-cluster.tpl")}"

  vars = {
    cluster_size                = "${var.cluster_size}"
    consul_datacenter           = "${var.consul_datacenter}"
    auto_join_subscription_id   = "${var.auto_join_subscription_id}"
    auto_join_tenant_id         = "${var.auto_join_tenant_id}"
    auto_join_client_id         = "${var.auto_join_client_id}"
    auto_join_secret_access_key = "${var.auto_join_client_secret}"
  }
}



resource "azurerm_public_ip" "hashistack-lb-ip" {
  name                         = "${var.consul_datacenter}-lb-ip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.environment_name}"
}

resource "azurerm_lb" "hashistack-lb" {
  name                = "${var.consul_datacenter}-lb"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.hashistack-lb-ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "hashistack-bpepool" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.hashistack-lb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_rule" "vault" {
  resource_group_name            = "${var.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.hashistack-lb.id}"
  name                           = "Vault"
  protocol                       = "Tcp"
  frontend_port                  = 8200
  backend_port                   = 8200
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.hashistack-bpepool.id}"
  probe_id                       = "${azurerm_lb_probe.vault.id}"
}

resource "azurerm_lb_probe" "vault" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.hashistack-lb.id}"
  protocol            = "http"
  name                = "vault"
  port                = 8200
  request_path        = "/v1/sys/health"

}

resource "azurerm_virtual_machine_scale_set" "hashistack" {
  name                = "${var.environment_name}-ss"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_A0"
    tier     = "Standard"
    capacity = 3
  }

  storage_profile_image_reference {
    id      =  "${var.custom_image_id}"
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "hashistack"
    admin_username = "${module.images.os_user}"
    admin_password = "none"
    custom_data    = "${base64encode(data.template_file.init.rendered)}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${module.images.os_user}/.ssh/authorized_keys"
      key_data = "${var.public_key_data}"
    }
  }

  network_profile {
    name    = "${var.environment_name}-profile"
    primary = true

    ip_configuration {
      name                                   = "PublicIPAddress"
      subnet_id                              = "${var.private_subnet_ids[0]}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.hashistack-bpepool.id}"]
    }
  }

  tags {
    environment_name  = "${var.environment_name}"
    consul_datacenter = "${var.consul_datacenter}"
  }

}
