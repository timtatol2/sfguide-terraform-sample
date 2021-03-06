terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "0.34.0"
    }
  }
}

provider "snowflake" {
#username = "Sunmi"
#password = "Sunmilola1"
account  = "tm21067"
region   = "ca-central-1.aws"
alias    = "sys_admin"
role     = "SYSADMIN"
}

resource "snowflake_database" "db" {
  provider = snowflake.sys_admin
  name     = var.snowflake_database_name
}

resource "snowflake_warehouse" "warehouse" {
  provider       = snowflake.sys_admin
  name           = var.snowflake_warehouse_name
  warehouse_size = "small"

  auto_suspend = 60
}



provider "snowflake" {
  alias = "security_admin"
  role  = "SECURITYADMIN"
}


resource "snowflake_role" "role" {
  provider = snowflake.security_admin
  name     = "${snowflake_database.db.name}_SVC_ROLE"
}


resource "snowflake_database_grant" "grant" {
  provider          = snowflake.security_admin
  database_name     = snowflake_database.db.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "snowflake_schema" "schema" {
  provider   = snowflake.sys_admin
  database   = snowflake_database.db.name
  name       = var.snowflake_schema_name
  is_managed = false
}


resource "snowflake_schema_grant" "grant" {
  provider          = snowflake.security_admin
  database_name     = snowflake_database.db.name
  schema_name       = snowflake_schema.schema.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "snowflake_warehouse_grant" "grant" {
  provider          = snowflake.security_admin
  warehouse_name    = snowflake_warehouse.warehouse.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = var.snowflake_username
  default_warehouse = snowflake_warehouse.warehouse.name
  default_role      = snowflake_role.role.name
  default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}


resource "snowflake_role_grants" "grants" {
  provider  = snowflake.security_admin
  role_name = snowflake_role.role.name
  users     = [snowflake_user.user.name]
}
