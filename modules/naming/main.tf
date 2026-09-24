# Single source of the naming scheme and the tag set. No resources: the
# calling environment computes both once and hands them to modules/azure/* and
# modules/databricks/*, so no module carries its own copy of the region map.

locals {
  # Azure's short region codes. Add to this map as new regions are needed;
  # an unmapped region fails loudly here (Invalid index) rather than
  # silently producing a name containing the string "null".
  region_short = {
    westeurope  = "weu"
    northeurope = "neu"
    uksouth     = "uks"
    eastus      = "eus"
  }
}
