resource "random_integer" "random" {
  min = 1
  max = 3
}

resource "random_uuid" "random" {
}

module "subscription" {
  source          = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = data.azurerm_subscription.current.subscription_id
}

module "naming" {
  source = "github.com/Azure-Terraform/example-naming-template.git?ref=v1.0.0"
}

module "metadata" {
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.5.1"

  naming_rules = module.naming.yaml

  market              = var.metadata.market
  location            = var.resource_group.location
  sre_team            = var.metadata.sre_team
  environment         = var.metadata.environment
  product_name        = var.metadata.product_name
  business_unit       = var.metadata.business_unit
  product_group       = var.metadata.product_group
  subscription_type   = var.metadata.subscription_type
  resource_group_type = var.metadata.resource_group_type
  subscription_id     = data.azurerm_subscription.current.id
  project             = var.metadata.project
}

module "resource_group" {
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v2.0.0"

  unique_name = var.resource_group.unique_name
  location    = var.resource_group.location
  names       = local.names
  tags        = local.tags
}

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v5.0.0"

  naming_rules = module.naming.yaml

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  names               = module.metadata.names
  tags                = module.metadata.tags

  enforce_subnet_names = false

  address_space = ["10.1.0.0/22"]
  aks_subnets = {
    hpcc = {
      private = {
        cidrs             = ["10.1.3.0/25"]
        service_endpoints = ["Microsoft.Storage"]
      }
      public = {
        cidrs             = ["10.1.3.128/25"]
        service_endpoints = ["Microsoft.Storage"]
      }
      route_table = {
        disable_bgp_route_propagation = true
        routes = {
          internet = {
            address_prefix = "0.0.0.0/0"
            next_hop_type  = "Internet"
          }
          local-vnet-10-1-0-0-21 = {
            address_prefix = "10.1.0.0/21"
            next_hop_type  = "vnetlocal"
          }
        }
      }
    }
  }
}

module "storage_account" {
  source = "github.com/Azure-Terraform/terraform-azurerm-storage-account.git?ref=v0.12.1"

  name                = lower(try("${var.admin.name}hpccsa${random_integer.random.result}", "hpccsa${random_integer.random.result}404"))
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.tags

  account_kind              = var.storage.account_kind
  replication_type          = var.storage.replication_type
  account_tier              = var.storage.account_tier
  access_tier               = var.storage.access_tier
  enable_large_file_share   = var.storage.enable_large_file_share
  shared_access_key_enabled = true
  access_list = {
    "my_ip" = data.http.host_ip.body
  }

  service_endpoints = {
    "aks_public"  = module.virtual_network.aks["hpcc"].subnets.public.id
    "aks_private" = module.virtual_network.aks["hpcc"].subnets.private.id
  }
}

resource "azurerm_storage_share" "storage_shares" {
  for_each = local.storage_shares

  name                 = each.key
  storage_account_name = module.storage_account.name
  quota                = each.value
  acl {
    id = random_uuid.random.result

    access_policy {
      permissions = "rwdl"
    }
  }
}
