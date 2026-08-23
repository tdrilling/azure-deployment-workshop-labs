# Azure Deployment Workshop - Lab 5: Hauptvorlage (Root-Modul)
#
# Bildet dieselbe Zielarchitektur wie Lab 4 (Bicep) ab (Ubuntu-VM mit
# Apache/PHP/MySQL/WordPress), diesmal mit Terraform statt Bicep/ARM.
# Orchestriert zwei Kind-Module: modules/network (VNet/Subnet/NSG/
# Public-IP/NIC) und modules/vm (die VM selbst). Details und Begruendungen
# siehe Instructions/05-terraform.md.
#
# WICHTIGER UNTERSCHIED ZU LAB 4: Bicep wird gegen eine VORHER per
# `az group create` angelegte Resource Group deployt (targetScope =
# 'resourceGroup'). Terraform-Deployments sind ueblicherweise Subscription-
# Scope -- die Resource Group ist hier deshalb selbst eine verwaltete
# Ressource (azurerm_resource_group.main) und landet mit im State. Ein
# separater "Resource-Group-anlegen"-Schritt entfaellt dadurch gegenueber
# Lab 4, siehe Instructions/05-terraform.md, Schritt-fuer-Schritt-Anleitung.
#
# Ablauf (Details siehe Instructions/05-terraform.md):
#   terraform init
#   terraform plan  -var-file="terraform.tfvars"
#   terraform apply -var-file="terraform.tfvars"

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # PRODUKTIONSHINWEIS: Ohne "backend"-Block landet der State lokal in
  # terraform.tfstate (siehe .gitignore -- diese Datei NIE committen). Fuer
  # Team-/Produktivbetrieb gehoert der State in ein Remote-Backend mit
  # Locking, z. B.:
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstateXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "lab5-lamp.tfstate"
  # }
  #
  # Fuer dieses Einmal-Demo-Lab bewusst NICHT konfiguriert -- siehe
  # Instructions/05-terraform.md, Abschnitt "Was ist neu gegenueber Lab 4".
}

provider "azurerm" {
  features {}

  # Optional, aber von HashiCorp empfohlen, sobald mehr als eine Subscription
  # am `az login`-Kontext haengt (sonst waehlt der Provider stillschweigend
  # die aktuell aktive Subscription aus der Azure-CLI):
  # subscription_id = "<CHANGE_ME_SUBSCRIPTION_ID>"
}

# -- Global eindeutiges DNS-Label fuer die Public IP, analog zu Biceps
#    uniqueString(resourceGroup().id)-Default in Lab 4. Terraform kennt keine
#    zur Resource Group passende deterministische Hash-Funktion vor deren
#    Anlage, daher hier ueber den random-Provider geloest. Nur verwendet,
#    wenn var.dns_label_prefix leer gelassen wird (Default). --
resource "random_string" "dns_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  tags = {
    lab           = "Lab5-Terraform"
    resourceGroup = var.resource_group_name
    application   = "wordpress"
  }

  dns_label_prefix = var.dns_label_prefix != "" ? var.dns_label_prefix : "lamp-tf-${random_string.dns_suffix.result}"
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  vnet_name                 = "vnet-lamp-tf"
  subnet_name               = "snet-lamp-tf"
  nsg_name                  = "nsg-lamp-tf"
  public_ip_name            = "pip-lamp-tf"
  nic_name                  = "nic-lamp-tf"
  vnet_address_prefix       = var.vnet_address_prefix
  subnet_address_prefix     = var.subnet_address_prefix
  ssh_source_address_prefix = var.ssh_source_address_prefix
  dns_label_prefix          = local.dns_label_prefix
  tags                      = local.tags
}

module "vm" {
  source = "./modules/vm"

  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  vm_name              = var.vm_name
  vm_size              = var.vm_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  network_interface_id = module.network.nic_id
  tags                 = local.tags
}
