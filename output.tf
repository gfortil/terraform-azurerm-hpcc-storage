output "resource_group_name" {
  value = module.resource_group.name
}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}

output "storage_account_name" {
  value = module.storage_account.name
}

output "location" {
  value = module.resource_group.location
}

output "private_subnet_id" {
  value = module.virtual_network.aks["hpcc"].subnets.private.id
}

output "public_subnet_id" {
  value = module.virtual_network.aks["hpcc"].subnets.public.id
}

output "route_table_id" {
  value = module.virtual_network.aks["hpcc"].route_table_id
}
