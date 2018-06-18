terraform {
  required_version = ">= 0.10.1"
}

provider "azurerm" {}

resource "azurerm_resource_group" "main" {
  name     = "${var.environment_name}"
  location = "${var.location}"
}

module "ssh_key" {
  source = "modules/ssh-keypair-data"

  private_key_filename = "${var.private_key_filename}"
}

module "network_west" {
  source                = "modules/network-azure"
  environment_name      = "${var.environment_name}-west"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  location              = "West US"
  network_cidr          = "172.31.0.0/16"
  network_cidrs_private = ["172.31.48.0/20"]
  network_cidrs_public  = ["172.31.0.0/20"]
  os                    = "${var.os}"
  public_key_data       = "${module.ssh_key.public_key_data}"
}

module "network_east" {
  source                = "modules/network-azure"
  environment_name      = "${var.environment_name}-east"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  location              = "East US"
  network_cidr          = "10.31.0.0/16"
  network_cidrs_private = ["10.31.48.0/20"]
  network_cidrs_public  = ["10.31.0.0/20"]
  os                    = "${var.os}"
  public_key_data       = "${module.ssh_key.public_key_data}"
}

module "consul_azure_west" {
  source                    = "modules/consul-azure"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  environment_name          = "${var.environment_name}-west"
  location                  = "West US"
  cluster_size              = "${var.cluster_size}"
  consul_datacenter         = "ll-consul-westus"
  custom_image_id           = "${var.custom_image_id_west}"
  os                        = "${var.os}"
  vm_size                   = "${var.consul_vm_size}"
  private_subnet_ids        = ["${module.network_west.subnet_private_ids}"]
  network_cidrs_private     = ["${var.network_cidrs_private}"]
  public_key_data           = "${module.ssh_key.public_key_data}"
  auto_join_subscription_id = "${var.auto_join_subscription_id}"
  auto_join_tenant_id       = "${var.auto_join_tenant_id}"
  auto_join_client_id       = "${var.auto_join_client_id}"
  auto_join_client_secret   = "${var.auto_join_client_secret}"
}

module "consul_azure_east" {
  source                    = "modules/consul-azure"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  environment_name          = "${var.environment_name}-east"
  location                  = "East US"
  cluster_size              = "${var.cluster_size}"
  consul_datacenter         = "ll-consul-eastus"
  custom_image_id           = "${var.custom_image_id_west}"
  os                        = "${var.os}"
  vm_size                   = "${var.consul_vm_size}"
  private_subnet_ids        = ["${module.network_east.subnet_private_ids}"]
  network_cidrs_private     = ["${var.network_cidrs_private}"]
  public_key_data           = "${module.ssh_key.public_key_data}"
  auto_join_subscription_id = "${var.auto_join_subscription_id}"
  auto_join_tenant_id       = "${var.auto_join_tenant_id}"
  auto_join_client_id       = "${var.auto_join_client_id}"
  auto_join_client_secret   = "${var.auto_join_client_secret}"
}
