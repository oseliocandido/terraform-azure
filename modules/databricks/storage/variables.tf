variable "environment" {
  type        = string
  description = "Deployment environment (\"dev\" or \"prod\")."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID -- output of environments/shared, not created by this module."
}

variable "access_connector_id" {
  type        = string
  description = "ARM resource ID of this environment's Databricks access connector (modules/databricks/workspaces's own output) -- the storage credential below wraps a reference to it."
}

variable "bronze_storage_root" {
  type        = string
  description = "abfss:// URL for the bronze external location -- from modules/analytics's bronze container. Environment-scoped, not domain-scoped: the raw landing layer isn't owned by any one business domain."
}

variable "landing_storage_roots" {
  type        = map(string)
  description = "Map of source system -> abfss:// URL for its dedicated landing container, one entry per modules/analytics's var.landing_source_systems (built by the calling environment from that module's landing_container_names output). Drives databricks_external_location.landing, databricks_volume.landing, and databricks_volume.landing_checkpoint's for_each -- adding a source system here is what creates its external location, volume, and checkpoint volume, mirroring modules/analytics's own landing_source_systems -> azurerm_storage_container.landing for_each on the Azure side."
}

variable "resource_group_name" {
  type        = string
  description = "This environment's Azure resource group name (modules/analytics's own output) -- needed by the pos_landing/ecommerce_landing external locations' managed_aqs file-event queue, which Databricks provisions into this resource group."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID -- same reason as resource_group_name, both required arguments for the managed_aqs file-event queue block."
}

variable "ci_group_name" {
  type        = string
  description = "grp-databricks-ci-dev / grp-databricks-ci-prod -- granted CREATE_EXTERNAL_LOCATION on the storage credential below, since Terraform (running as this group's member, sp-terraform-<env>) has to keep reading/managing that credential on every future plan, and owning it belongs to grp-databricks-platform-<env> instead (see main.tf's ownership comment)."
}

variable "workspace_id" {
  type        = string
  description = "This environment's own workspace ID -- used for the ingestion catalog's workspace-catalog binding, same reasoning as modules/databricks/unity_catalog's identical variable."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-dev / sp-terraform-prod -- granted ongoing USE_CATALOG/USE_SCHEMA/CREATE_SCHEMA/CREATE_VOLUME/READ METADATA/READ VOLUME on the ingestion catalog below, ungated by enable_grants (same reasoning as ci_group_name's own grants elsewhere in this module: infrastructure CI needs to keep functioning, not a business data-access grant). Needed because owning the ingestion catalog belongs to grp-databricks-platform-<env>, not to CI, and CREATE_CATALOG at the metastore level (databricks_grants.metastore_admins, root module) doesn't cascade to privileges on this specific, already-existing catalog -- same non-cascading-ownership problem as every other CI grant in this file. No CREATE_TABLE -- see that grant's own comment in main.tf for why."
}

variable "ingestion_catalog_storage_root" {
  type        = string
  description = "abfss:// URL for the ingestion catalog's own managed-storage root -- from modules/analytics's \"managed-ingestion\" container (its additional_domains output, even though \"ingestion\" isn't a business domain -- that variable is really \"additional managed-storage owners\", not literally domains). Backs the checkpoint volumes below; the ingestion catalog needs its own registered external location for the same reason every domain catalog does (see modules/databricks/unity_catalog's identical requirement)."
}

variable "bronze_consumer_group_name" {
  type        = string
  description = "grp-sales-data-engineers-<env> today -- the one group granted SELECT on the ingestion catalog's bronze schema and READ VOLUME on the two landing volumes below. A single bare string, not a list, because only sales has a real, PRD-backed consumer for this raw data right now (see main.tf's own \"Ingestion catalog\" comment) -- add a second databricks_grants block by hand if/when a second domain genuinely needs the same raw feed, rather than building a list/for_each mechanism for a need that doesn't exist yet."
}

variable "bronze_consumer_can_write" {
  type        = bool
  default     = false
  description = "Also lets bronze_consumer_group_name experiment with ingestion by hand: READ VOLUME + WRITE VOLUME on the checkpoints volume and CREATE_TABLE on the bronze schema. Only meaningful when enable_grants is true. Set true in dev; leave false in prod, where the (future) pipeline service principal should hold these instead of a human group."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates bronze_consumer_group_name's own grants below (catalog USE_CATALOG, bronze schema SELECT, landing-volume READ VOLUME) -- separate from ci_group_name/ci_service_principal_name's own grants in this module, which stay ungated since they're infrastructure CI needs regardless of whether grp-sales-data-engineers-<env> exists yet. Same reasoning as modules/databricks/unity_catalog's identical variable."
}
