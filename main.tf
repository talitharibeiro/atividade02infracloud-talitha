terraform {
  required_version = " > 0.13"

  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = " > 2.26"
    }
  }
}

provider "azurerm" {
  features {
    
  }
}

resource "azurerm_resource_group" "rg-talitha" {
  name     = "aulainfracloudterra"
  location = "centralus"
}

resource "azurerm_virtual_network" "vnet-talitha" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-talitha.location
  resource_group_name = azurerm_resource_group.rg-talitha.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    disciplina = " Infrastructure"
    professor =" Joao"
    aula = "02"
  }
}

resource "azurerm_subnet" "subnet-talitha" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-talitha.name
  virtual_network_name = azurerm_virtual_network.vnet-talitha.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-talitha" {
  name                    = "publicip"
  location                = azurerm_resource_group.rg-talitha.location
  resource_group_name     = azurerm_resource_group.rg-talitha.name
  allocation_method       = "Static"
}

resource "azurerm_network_security_group" "nsg-talitha" {
  name                = "nsg"
  location            = azurerm_resource_group.rg-talitha.location
  resource_group_name = azurerm_resource_group.rg-talitha.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-talitha" {
  name                = "nic"
  location            = azurerm_resource_group.rg-talitha.location
  resource_group_name = azurerm_resource_group.rg-talitha.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.subnet-talitha.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ip-talitha.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-talitha" {
  network_interface_id      = azurerm_network_interface.nic-talitha.id
  network_security_group_id = azurerm_network_security_group.nsg-talitha.id
}

resource "azurerm_storage_account" "sa-talitha" {
  name                     = "satalitha"
  resource_group_name      = azurerm_resource_group.rg-talitha.name
  location                 = azurerm_resource_group.rg-talitha.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  
}

resource "azurerm_linux_virtual_machine" "vm-talitha" {
  name                = "vm-talitha"
  resource_group_name = azurerm_resource_group.rg-talitha.name
  location            = azurerm_resource_group.rg-talitha.location
  size                = "Standard_D4ads_v5" 

  network_interface_ids = [
    azurerm_network_interface.nic-talitha.id,
  ]

  admin_username        = var.user
  admin_password = var.password
  disable_password_authentication =  false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "maydisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.sa-talitha.primary_blob_endpoint
  }
}

data "azurerm_public_ip" "ip-talitha-data" {
  name = azurerm_public_ip.ip-talitha.name
  resource_group_name = azurerm_resource_group.rg-talitha.name
}

variable "user" {
  description = "user da máquina"
  type = string
}

variable "password" {
}

resource "null_resource" "install-webserver" {

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-talitha-data.ip_address
    user = var.user
    password = var.password
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm-talitha
  ]
}

resource "null_resource" "upload-app" {

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-talitha-data.ip_address
    user = var.user
    password = var.password
  }

  provisioner "file" {
   source = "app"
   destination = "/home/adminuser"
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm-talitha
  ]
}