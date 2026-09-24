output "suffix" {
  description = "<workload>-<environment>-<region short>-<instance>, e.g. analytics-dev-neu-01. Resource names are a type prefix plus this suffix."
  value = join("-", [
    var.workload,
    var.environment,
    local.region_short[var.location],
    format("%02d", var.instance),
  ])
}

output "tags" {
  description = "The base tags merged with workload and environment. Apply to every taggable resource."
  value = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
  })
}
