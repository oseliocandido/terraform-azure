# Single source of the naming scheme and the tag set. No resources: the
# calling environment computes both once and hands them to modules/azure/* and
# modules/databricks/*, so no module carries its own copy of the region map.

locals {
  # Azure short region codes. Add regions as needed; an unmapped region fails
  # here instead of producing a name with "null" in it.
  region_short = {
    westeurope  = "weu"
    northeurope = "neu"
    uksouth     = "uks"
    eastus      = "eus"
  }
}
