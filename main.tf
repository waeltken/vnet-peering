provider "azurerm" {
  features {
  }
}

terraform {
  backend "azurerm" {
    resource_group_name  = "default"
    storage_account_name = "tfstateaia"
    container_name       = "tfstate"
    key                  = "vnet-peering.tfstate"
  }
}

locals {
  location = "West Europe"
}

resource "azurerm_resource_group" "example" {
  name     = "vnet-peering-rg"
  location = local.location
}

resource "azurerm_virtual_network" "vnet_1" {
  name                = "vnet-1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["172.16.0.0/16"]
}

resource "azurerm_subnet" "subnet_1_1" {
  name                 = "subnet-1-1"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet_1.name
  address_prefixes     = ["172.16.1.0/24"]
}

resource "azurerm_virtual_network" "vnet_2" {
  name                = "vnet-2"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["172.32.0.0/16"]
}

resource "azurerm_subnet" "subnet_2_1" {
  name                 = "subnet-2-1"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet_2.name
  address_prefixes     = ["172.32.1.0/24"]
}

resource "azurerm_virtual_network_peering" "peering_1_to_2" {
  name                         = "vnet-peering"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.vnet_1.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_2.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "peering_2_to_1" {
  name                         = "vnet-peering"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.vnet_2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_1.id
  allow_virtual_network_access = true
}

resource "azurerm_public_ip" "pip" {
  name                = "vm1-pip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "inbound" {
  name                = "vm1-inbound"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic_1" {
  name                = "nic_1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_1_1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "sg1" {
  network_interface_id      = azurerm_network_interface.nic_1.id
  network_security_group_id = azurerm_network_security_group.inbound.id
}

resource "azurerm_network_interface" "nic_2" {
  name                = "nic_2"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_2_1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_1" {
  name                = "vm1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = var.vm_username
  network_interface_ids = [
    azurerm_network_interface.nic_1.id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202208100"
  }
}

resource "azurerm_linux_virtual_machine" "vm_2" {
  name                = "vm2"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = var.vm_username
  network_interface_ids = [
    azurerm_network_interface.nic_2.id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202208100"
  }
}
