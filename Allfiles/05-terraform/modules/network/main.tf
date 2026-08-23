# Azure Deployment Workshop - Lab 5: Netzwerk-Modul
#
# Erstellt dasselbe Netzwerk-Rueckgrat wie Lab 4s modules/network.bicep:
# VNet + Subnet, NSG mit Regeln fuer SSH (22) und HTTP (80), eine statische
# Standard-Public-IP mit DNS-Label sowie die NIC, die alles verbindet.
#
# UNTERSCHIED ZU BICEP: azurerm bildet die Subnet<->NSG-Verknuepfung nicht
# als verschachtelte Eigenschaft ab (wie subnets[].properties.
# networkSecurityGroup.id in Bicep), sondern als eigene Assoziations-
# Ressource (azurerm_subnet_network_security_group_association) -- ein
# reines Provider-Modellierungsdetail, keine funktionale Abweichung.

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Nur SSH und HTTP erlauben, alles andere greift ueber die impliziten
  # Azure-Standardregeln (DenyAllInBound am Ende der Prioritaetenkette).
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_prefix]
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Standard-SKU Public IP, statisch (Basic-SKU unterstuetzt seit 30.09.2025
# keine neuen Deployments mehr, siehe Lab 4) mit DNS-Label fuer einen
# stabilen FQDN. Standard-SKU verlangt in azurerm zwingend
# allocation_method = "Static".
resource "azurerm_public_ip" "pip" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label_prefix
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}
