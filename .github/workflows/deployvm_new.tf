
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.57.0"
    }
  }
}
provider "azurerm" {
  features {}
}

variable "prefix" {
  default = "tfvmex"
}
resource "azurerm_resource_group" "rg" {
  name     = "github-runners"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name      = "github-runners-v"
  address_space       = ["10.0.0.0/16"]
  location   = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "internal" {
  name           = "github-runners-subnet"
  address_prefixes = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "mynsg1" {
  name                = "github-runnersSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  security_rule {
    name                       = "allow_ssh"
    priority                   =  "100"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
  }
}

resource "azurerm_public_ip" "mypublicip" {
  name                = "github-runners-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  count               = 10
  name                = "github-runner-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
    ip_configuration {
      name             = "github-runner-ipconfig"
      subnet_id        = azurerm_subnet.internal.id
      private_ip_address_allocation = "Dynamic"
}
}

resource "azurerm_virtual_machine" "vm" {
  count               = 10
 // name                = "github-runner-vm-${count.index}"
  name                = "${var.prefix}-vm-${count.index}"
  location            = azurerm_resource_group.rg.location
  network_interface_ids = azurerm_network_interface.nic[count.index]
  resource_group_name = azurerm_resource_group.rg.name
  vm_size             = "Standard_DS1"
  delete_os_disk_on_termination = true
   #ic[count.index].id]

   storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }
  
  storage_os_disk {
    name   = "myosdisk"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }
  os_profile {
    computer_name  = "${azurerm_virtual_machine.vm[count.index].name}"
    admin_username = "adminuser"
    admin_password = "p@ssw0rd1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/adminuser/.ssh/authorized_keys"
      key_data = "ssh-rsa abcdefijklmnopqrstuvwxyz1234567890== adminuser"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update apt install -y docker.io",
      "sudo usermod -aG docker $USER",
      "sudo systemctl enable docker.service",
      "curl -sL https://deb.nodesource.com/setup.x | sudo -E bash -",
      " apt-get install -y npm install -g @actions/runner@.282.3mkdir actions-runner && cd actions-runner",
      "curlO -L https://github.com/actions/runner/releases/download/v2.282.3/actions-runner-linux-x64-2.282.3.tar.gz",
      "tar xzf ./actions-runner-linux-x64-2.282.3.tar.gz",
      "rm --linux-x642.2823.tar.gz",
      "./config.sh --url https://github.com/[org]/repo] --token [TOKEN] --unattended"
    ]
  }
  
  depends_on = [
    azurerm_virtual_network.vnet
    ]
}
