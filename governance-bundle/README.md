# governance-bundle

Creates the SQL functions (column mask, row filter) that the ABAC policies in
`../governance` call. Needs the `security` schema from `platform`
(`enable_security_schema = true`).

## Order

```
1. platform     terraform apply            workspace, catalogs, security schema, tag policies
2. this bundle  bundle deploy + run        functions in <catalog>.security
3. governance   terraform apply            ABAC policies
```

## Run it

```bash
cd platform
export DATABRICKS_HOST=$(terraform output -raw workspace_url)
export WAREHOUSE_ID=$(terraform output -raw warehouse_id)

cd ../governance-bundle
databricks bundle deploy -t dev --var="warehouse_id=$WAREHOUSE_ID"
databricks bundle run create_security_functions -t dev --var="warehouse_id=$WAREHOUSE_ID"
```

Authenticate the CLI the same way as Terraform (`az login` locally, OIDC in CI).
The identity needs `CAN_USE` on the warehouse and `CREATE_FUNCTION` on each
`security` schema (granted by `platform`).

## Adding a domain

Add a task to `resources/security_functions.yml` with the new catalog name.

## Not yet verified

The bundle was written without running it. Check `sql_task` file and parameter
handling, and the `IDENTIFIER(:catalog || ...)` form in the SQL, on a dev
deploy before relying on it.
