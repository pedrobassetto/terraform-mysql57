/**
  @Author: Pedro Eduardo Bassetto
*/

#REQUIRED IN AZURE
#  az provider register --namespace Microsoft.Network
#  az provider register --namespace Microsoft.Compute

# Configure the Azure provider
terraform {
    required_version = ">= 0.14.9"

    required_providers {
        azurerm = {
          source = "hashicorp/azurerm"
          version = ">= 2.26"
        }
    }
}

provider "azurerm" {
    skip_provider_registration = true
    features {}
}

#Create resource group
resource "azurerm_resource_group" "rg" {
  name     = "rgAtvTerraform"
  location = "eastus"
}

#Create virtual network
resource "azurerm_virtual_network" "vn" {
  name                = "atv-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

#Create subnet 
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

#Create public ip
resource "azurerm_public_ip" "ip" {
  name                = "atv-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

#Create Firewall
resource "azurerm_network_security_group" "nsg" {
  name                = "atv-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  #Allow ssh port 
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

  #Allow sql port
  security_rule {
    name                       = "mysql"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

#Create network inferface 
resource "azurerm_network_interface" "nic" {
  name                = "atv-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "atv-configuration"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}

#Firewall x Network Interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#Create virtual machine
resource "azurerm_virtual_machine" "main" {
  name                  = "atv-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  #OS
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  #Disk
  storage_os_disk {
    name              = "atv-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  #Profile
  os_profile {
    computer_name  = "mysqlvm"
    admin_username = "adminazure"
    admin_password = "Adminazure1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "atv-tf"
  }
}

#Wait 30 seconds after create VM
resource "time_sleep" "wait_30_seconds" {
  depends_on = [azurerm_virtual_machine.main]
  create_duration = "30s"
}

#Upload mysql configuration file
resource "null_resource" "upload" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "adminazure"
            password = "Adminazure1234!"
            host = azurerm_public_ip.ip.ip_address
        }
        source = "mysql"
        destination = "/home/adminazure"
    }

    depends_on = [ time_sleep.wait_30_seconds ]
}

#Apt update and mysql install
resource "null_resource" "install" {
    triggers = {
        order = null_resource.upload.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "adminazure"
            password = "Adminazure1234!"
            host = azurerm_public_ip.ip.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo cp -f /home/adminazure/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20"
        ]
    }
}

