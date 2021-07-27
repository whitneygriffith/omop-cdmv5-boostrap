provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "omop_rg" {
  name     = "${var.prefix}-${var.environment}-omop-rg"
  location = var.omop_rg_location
}

/*

resource "azurerm_storage_account" "omop_sa" {
  name                     = "${var.prefix}${var.environment}omopsa"
  resource_group_name      = azurerm_resource_group.omop_rg.name
  location                 = azurerm_resource_group.omop_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "omop_container" {
  name                  = "vocab-v5"
  storage_account_name  = azurerm_storage_account.omop_sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "data_container" {
  name                  = "synpuf1k"
  storage_account_name  = azurerm_storage_account.omop_sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "example" {
  name                   = "synpuf1k_5.2.2.zip"
  storage_account_name   = azurerm_storage_account.omop_sa.name
  storage_container_name = azurerm_storage_container.data_container.name
  type                   = "Block"
  source                 = "../synpuf_data/synpuf1k_omop_cdm_5.2.2.zip"
}
 */

resource "azurerm_mssql_server" "omop_sql_server" {
  name                         = "${var.prefix}-${var.environment}-omop-sql-server"
  resource_group_name          = azurerm_resource_group.omop_rg.name
  location                     = azurerm_resource_group.omop_rg.location
  version                      = "12.0"
  administrator_login          = "omop_admin"
  administrator_login_password = var.omop_password
  minimum_tls_version          = "1.2"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_sql_firewall_rule" "open_firewall" {
  name                = "SQLFirewallRule1"
  resource_group_name = azurerm_resource_group.omop_rg.name
  server_name         = azurerm_mssql_server.omop_sql_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

resource "azurerm_sql_firewall_rule" "allow_azure_services" {
  name                = "SQLFirewallRule2"
  resource_group_name = azurerm_resource_group.omop_rg.name
  server_name         = azurerm_mssql_server.omop_sql_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_mssql_database" "OHDSI-CDMV5" {
  name           = "${var.prefix}-${var.environment}-omop-db"
  server_id      = azurerm_mssql_server.omop_sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = var.omop_db_size
  sku_name       = var.omop_db_sku
  zone_redundant = true

  # initialize database by creating tables and schemas
  provisioner "local-exec" {
        command = "sqlcmd -U omop_admin -P ${var.omop_password} -S ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net -d ${var.prefix}-${var.environment}-omop-db -i ../SQL/OMOP_CDM_sql_server_ddl.sql -o ${var.log_file}"
    }
  # enable change data capture 
  provisioner "local-exec" {
        command = "sqlcmd -U omop_admin -P ${var.omop_password} -S ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net -d ${var.prefix}-${var.environment}-omop-db -i ../SQL/enable_change_data.sql -o ${var.log_file}"
  }

  # import cdm v5 vocabulary
  provisioner "local-exec" {
        command = "../scripts/vocab_import.sh ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net ${var.prefix}-${var.environment}-omop-db omop_admin ${var.omop_password}"
    }

  # convert vocabulary table columns from varchar to date
  provisioner "local-exec" {
      command = "sqlcmd -U omop_admin -P ${var.omop_password} -S ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net -d ${var.prefix}-${var.environment}-omop-db -i ../SQL/convert_varchar_to_date.sql -o ${var.log_file}"
  }

  # import synpuf data
  provisioner "local-exec" {
        command = "../scripts/synpuf_data_import.sh ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net ${var.prefix}-${var.environment}-omop-db omop_admin ${var.omop_password}"
    }

  # add indices and primary keys
  provisioner "local-exec" {
      command = "sqlcmd -U omop_admin -P ${var.omop_password} -S ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net -d ${var.prefix}-${var.environment}-omop-db -i ../SQL/OMOP_CDM_sql_server_indexes.sql -o ${var.log_file}"
  }
  # add foreign key constraints
  provisioner "local-exec" {
      command = "sqlcmd -U omop_admin -P ${var.omop_password} -S ${var.prefix}-${var.environment}-omop-sql-server.database.windows.net -d ${var.prefix}-${var.environment}-omop-db -i ../SQL/OMOP_CDM_sql_server_constraints.sql -o ${var.log_file}"
  }

}

# This creates the plan that the service use
resource "azurerm_app_service_plan" "omop_asp" {
  name                = "${var.prefix}-omop-asp"
  location            = "${azurerm_resource_group.omop_rg.location}"
  resource_group_name = "${azurerm_resource_group.omop_rg.name}"
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# This creates the service definition
resource "azurerm_app_service" "omop_app_service" {
  name                = "${var.prefix}-omop-appservice"
  location            = "${azurerm_resource_group.omop_rg.location}"
  resource_group_name = "${azurerm_resource_group.omop_rg.name}"
  app_service_plan_id = "${azurerm_app_service_plan.omop_asp.id}"

  site_config {
    app_command_line = ""
    linux_fx_version = "DOCKER|${var.docker_image}:${var.docker_image_tag}"
    always_on        = true
  }

  app_settings = {
    "WEBAPI_RELEASE" = "2.9.0"
    "WEBAPI_WAR" =  "WebAPI-2.9.0.war"
    "WEBSITES_PORT" = "8080"
  }
}
