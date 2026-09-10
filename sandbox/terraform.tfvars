environment   = "sandbox"
budget_amount = 5

# This environment is throwaway infra for testing module changes -- it is
# never registered in Unity Catalog and carries no real data. Safe to
# destroy and recreate freely, unlike dev/prod.
location = "northeurope"
