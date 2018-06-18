resource "azurerm_virtual_network_peering" "west-east" {
  name                      = "west-east-peer"
  allow_virtual_network_access = "true"
  resource_group_name       = "${var.environment_name}"
  virtual_network_name      = "${module.network_west.network_name}"
  remote_virtual_network_id = "${module.network_east.network_id}"
}

resource "azurerm_virtual_network_peering" "east-west" {
  name                      = "east-west-peer"
  allow_virtual_network_access = "true"
  resource_group_name       = "${var.environment_name}"
  virtual_network_name      = "${module.network_east.network_name}"
  remote_virtual_network_id = "${module.network_west.network_id}"
}
