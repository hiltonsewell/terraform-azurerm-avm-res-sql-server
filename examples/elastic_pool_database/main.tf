terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}


# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "AustraliaEast"
  name     = module.naming.resource_group.name_unique
}

resource "random_password" "admin_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
  special          = true
}

locals {
  databases = {
    sample_database = {
      name             = "sample_database"
      create_mode      = "Default"
      collation        = "SQL_Latin1_General_CP1_CI_AS"
      elastic_pool_key = "sample_pool"
      license_type     = "LicenseIncluded"
      max_size_gb      = 50
      sku_name         = "ElasticPool"

      short_term_retention_policy = {
        retention_days           = 1
        backup_interval_in_hours = 24
      }
    }
  }
  elastic_pools = {
    sample_pool = {
      name = "sample_pool"
      sku = {
        name     = "StandardPool"
        capacity = 50
        tier     = "Standard"
      }
      per_database_settings = {
        min_capacity = 50
        max_capacity = 50
      }
      maintenance_configuration_name = "SQL_Default"
      zone_redundant                 = false
      license_type                   = "LicenseIncluded"
      max_size_gb                    = 50
    }
  }
}

# This is the module call
module "sql_server" {
  source = "../../"

  location                     = azurerm_resource_group.this.location
  resource_group_name          = azurerm_resource_group.this.name
  server_version               = "12.0"
  administrator_login          = "mysqladmin"
  administrator_login_password = random_password.admin_password.result
  databases                    = local.databases
  elastic_pools                = local.elastic_pools
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  # ...
  enable_telemetry = var.enable_telemetry
  name             = module.naming.sql_server.name_unique
}
