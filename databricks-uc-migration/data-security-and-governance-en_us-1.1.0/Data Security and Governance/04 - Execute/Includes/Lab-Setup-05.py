# Databricks notebook source
# MAGIC %run ./_common

# COMMAND ----------

# generate user-friendly and safe catalog names based on username
import hashlib

DATA_ADJECTIVES = [
    "Accelerated",
    "Accurate",
    "Audited",
    "Authorized",
    "Canonical",
    "Clean",
    "Compliant",
    "Consistent",
    "Curated",
    "Defined",
    "Distributed",
    "Efficient",
    "Elastic",
    "Encrypted",
    "Explainable",
    "Fast",
    "Federated",
    "Global",
    "Governed",
    "Hardened",
    "Hybrid",
    "Idempotent",
    "Incremental",
    "Inspectable",
    "Insightful",
    "Instrumented",
    "Isolated",
    "LeastPrivilege",
    "LowLatency",
    "Masked",
    "Measurable",
    "Modular",
    "Monitorable",
    "MultiTenant",
    "Observable",
    "Optimized",
    "Parallel",
    "Partitioned",
    "Private",
    "Queryable",
    "Realtime",
    "Reliable",
    "Replicated",
    "Resilient",
    "Responsive",
    "Scalable",
    "Scoped",
    "Searchable",
    "Secure",
    "Serverless",
    "Signed",
    "Streamlined",
    "Swift",
    "Tokenized",
    "Traceable",
    "Transparent",
    "Trusted",
    "Turbo",
    "Validated",
    "Vectorized",
    "Verified",
    "Visible",
]

DATA_NOUNS = [
    "App",
    "Archive",
    "Batch",
    "Bitmap",
    "Block",
    "Boundary",
    "Catalog",
    "Cluster",
    "Column",
    "Contract",
    "Credential",
    "Dashboard",
    "Data",
    "Database",
    "Dataset",
    "Domain",
    "Embedding",
    "Endpoint",
    "Engine",
    "Entitlement",
    "Executor",
    "Experiment",
    "Feature",
    "File",
    "Forecast",
    "Glossary",
    "Graph",
    "Grant",
    "Index",
    "Job",
    "Key",
    "Lakehouse",
    "Ledger",
    "Lineage",
    "Log",
    "Mart",
    "Metastore",
    "Metric",
    "Model",
    "Namespace",
    "Notebook",
    "Object",
    "Partition",
    "Pipeline",
    "Policy",
    "Privilege",
    "Query",
    "Record",
    "Registry",
    "Report",
    "Role",
    "Row",
    "Runner",
    "Schema",
    "Segment",
    "Service",
    "Shard",
    "Snapshot",
    "Store",
    "Stream",
    "Table",
    "Task",
    "Vector",
    "View",
    "Volume",
    "Warehouse",
    "Workflow",
]

def data_catalog_name(seed: str, attempt: int = 0) -> str:
    """
    Deterministic catalog name generator.

    Same seed + attempt => same name
    Increment attempt to get next deterministic candidate
    """

    digest = hashlib.sha256(
        f"{seed}|attempt:{attempt}".encode("utf-8")
    ).digest()

    adjective = DATA_ADJECTIVES[digest[0] % len(DATA_ADJECTIVES)]
    noun = DATA_NOUNS[digest[1] % len(DATA_NOUNS)]

    return f"{adjective}_{noun}".lower()

from databricks.sdk.errors import BadRequest

@DBAcademyHelper.add_init
def init_catalog(self):
    catalog = None

    for attempt in range(10):
        catalog_name = data_catalog_name(seed=self.username, attempt=attempt)
        try:
            catalog = self.workspace.catalogs.create(name=catalog_name)
            break
        except BadRequest:
            catalog = self.workspace.catalogs.get(catalog_name);
            if catalog.owner == self.username:
                break
    else:
        catalog_name = ''.join(c for c in self.username.split('@')[0] if c.isalnum())
        try:
            catalog = self.workspace.catalogs.create(name=catalog_name)
        except BadRequest:
            catalog = self.workspace.catalogs.get(catalog_name);
            if catalog.owner != self.username:
                catalog = None
        
    if not catalog:
        print(f"Unable to create catalog")
        return False

    self.catalog_name = catalog.name
    spark.sql(f'USE CATALOG {self.catalog_name}')

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.errors import PySparkException

@DBAcademyHelper.add_method
def check_schema(self):

    def get_schema_map(df):
        return {f.name.lower(): f.dataType.simpleString() for f in df.schema.fields}

    table_names = [row[0] for row in spark.sql('SHOW TABLES IN hive_metastore.finance').select('tableName').collect() if row[0] != '_sqldf']

    for t in table_names:
        src_df = spark.table(f"hive_metastore.finance.{t}")
        dst_df = spark.table(t)

        src_schema = get_schema_map(src_df)
        try:
            dst_schema = get_schema_map(dst_df)
        except PySparkException:
            assert False, f"❌ {t} was not migrated to the destination schema"

        missing_in_dst = sorted(set(src_schema) - set(dst_schema))
        extra_in_dst   = sorted(set(dst_schema) - set(src_schema))
        type_mismatches = sorted(
            (c, src_schema[c], dst_schema[c])
            for c in set(src_schema).intersection(dst_schema)
            if src_schema[c] != dst_schema[c]
        )

        assert not missing_in_dst, f"❌ Missing columns in {t}: {missing_in_dst}"
        assert not extra_in_dst, f"❌ Extra columns in {t}: {extra_in_dst}"
        assert not type_mismatches, f"❌ Type mismatches in {t}: {type_mismatches}"
        assert dst_df.count() == src_df.count(), f"❌ Row count mismatch in {t}"
        print(f'✅ "{t}" migrated successfully')

# COMMAND ----------

@DBAcademyHelper.add_method
def check_privileges(self):

    # get list of tables in current schema
    table_names = [row[0] for row in spark.sql('SHOW TABLES').select('tableName').collect() if row[0] != '_sqldf']

    # we expect SELECT on the SCHEMA for all except expenses, where we expect MODIFY on the table
    for t in table_names:
        if t == 'expenses':
            expected = {
                ("MODIFY","TABLE"),
                ("SELECT","SCHEMA")
            }
        else:
            expected = {
                ("SELECT","SCHEMA")
            }

        actual = set(
            (row.ActionType, row.ObjectType)
            for row in spark.sql(f"SHOW GRANTS ON {t}")
                .where("Principal = 'account users'")
                .select("ActionType","ObjectType")
                .collect()
        )

        assert actual == expected, f"❌ {t} has incorrect privilege assignment"
        print(f"✅ {t} has correct privilege assignment")

    # for schema, we expect USE SCHEMA and SELECT
    s = spark.catalog.currentDatabase()
    expected = {
        ("USE SCHEMA","SCHEMA"),
        ("SELECT","SCHEMA")
    }

    actual = set(
        (row.ActionType, row.ObjectType)
        for row in spark.sql(f"SHOW GRANTS ON SCHEMA {s}")
            .where("Principal = 'account users'")
            .select("ActionType","ObjectType")
            .collect()
    )

    assert actual == expected, f"❌ {s} has incorrect privilege assignment"
    print(f"✅ {s} has correct privilege assignment")

    # for catalog, we expect just USE CATALOG
    c = spark.catalog.currentCatalog()
    expected = {
        ("USE CATALOG","CATALOG")
    }

    actual = set(
        (row.ActionType, row.ObjectType)
        for row in spark.sql(f"SHOW GRANTS ON CATALOG {c}")
            .where("Principal = 'account users'")
            .select("ActionType","ObjectType")
            .collect()
    )

    assert actual == expected, f"❌ {c} has incorrect privilege assignment"
    print(f"✅ {c} has correct privilege assignment")

# COMMAND ----------

DA = DBAcademyHelper()
DA.init()