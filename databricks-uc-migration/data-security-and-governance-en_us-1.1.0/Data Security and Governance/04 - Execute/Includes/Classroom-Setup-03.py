# Databricks notebook source
# MAGIC %pip install faker
# MAGIC dbutils.library.restartPython()

# COMMAND ----------

# MAGIC %run ./_common

# COMMAND ----------

@DBAcademyHelper.add_method
def table(self, name: str):
    if spark.catalog.tableExists(name):
        return spark.table(name).limit(1).count() > 0

    return False

# COMMAND ----------

@DBAcademyHelper.add_method
def clear_tags(self):
    for row in spark.sql(f"""
                         SELECT table_name, column_name, tag_name
                         FROM information_schema.column_tags
                         WHERE catalog_name = '{self.catalog_name}' AND schema_name = '{self.schema_name}'
                         """).collect():
        spark.sql(f"ALTER TABLE {row['table_name']} ALTER COLUMN {row['column_name']} UNSET TAGS (\"{row['tag_name']}\")")
        print(f"Removed \"{row['tag_name']}\" tag from {row['table_name']}.{row['column_name']}")

# COMMAND ----------

from faker import Faker

@DBAcademyHelper.add_init
def init_general(self):
    self.fake = Faker()
    self.new_dims = False

    self.catalog_name = 'law_prd'
    spark.sql(f'CREATE CATALOG IF NOT EXISTS {self.catalog_name}')
    spark.sql(f'USE CATALOG {self.catalog_name}')

    self.schema_name = 'traffic'
    spark.sql(f'CREATE SCHEMA IF NOT EXISTS {self.schema_name}')
    spark.sql(f'USE SCHEMA {self.schema_name}')

# COMMAND ----------

@DBAcademyHelper.add_init
def init_driver_dim(self):
    self.driver_dim = f"{self.catalog_name}.{self.schema_name}.driver_dim"

    if self.table(self.driver_dim):
      return

    print(f"Initializating new table {self.driver_dim}")

    self.new_dims = True
    num_drivers = 100

    spark.sql(f"""
              CREATE OR REPLACE TABLE {self.driver_dim}
              ( driver_id STRING,
                name STRING,
                dob DATE,
                license_number STRING,
                address STRING,
                phone_number STRING,
                CONSTRAINT driver_pk PRIMARY KEY (driver_id)
              )""")
    
    drivers = [
      [
        str(i),
        f'{self.fake.last_name()}, {self.fake.first_name()}',
        self.fake.date_of_birth(minimum_age=16, maximum_age=90).strftime("%Y-%m-%d"),
        self.fake.bothify(text="???-#######").upper(),
        self.fake.address().replace("\n", ", "),
        self.fake.phone_number()
      ] for i in range(1, num_drivers + 1)
    ]

    values_string = ','.join('(' + ','.join('"' + s + '"' for s in d) + ')' for d in drivers)
    spark.sql(f"INSERT INTO {self.driver_dim} VALUES {values_string}")

# COMMAND ----------

import datetime
import random

@DBAcademyHelper.add_init
def init_vehicle_dim(self):
    self.vehicle_dim = f"{self.catalog_name}.{self.schema_name}.vehicle_dim"

    if self.table(self.vehicle_dim):
      return

    print(f"Initializating new table {self.vehicle_dim}")

    self.new_dims = True
    num_vehicles = 50
    CURRENT = datetime.date.today().year

    spark.sql(f"""
              CREATE OR REPLACE TABLE {self.vehicle_dim}
              ( vehicle_id STRING,
                make STRING,
                model STRING,
                year INT,
                color STRING,
                vin STRING,
                plate STRING,
                state STRING,
                CONSTRAINT vehicle_pk PRIMARY KEY (vehicle_id)
              )""")

    vehicle_catalog = {
        "Toyota": {"Camry": (2012, CURRENT), "Corolla": (2010, CURRENT), "RAV4": (2015, CURRENT), "Highlander": (2014, CURRENT)},
        "Honda": {"Civic": (2006, CURRENT), "Accord": (2008, CURRENT), "CR-V": (2012, CURRENT), "HR-V": (2016, CURRENT)},
        "Ford": {"F-150": (2000, CURRENT), "Escape": (2008, CURRENT), "Mustang": (2005, CURRENT), "Explorer": (2011, CURRENT)},
        "Chevrolet": {"Silverado": (2007, CURRENT), "Equinox": (2010, CURRENT), "Malibu": (2013, CURRENT), "Tahoe": (2008, CURRENT)},
        "Nissan": {"Altima": (2010, CURRENT), "Rogue": (2014, CURRENT), "Sentra": (2012, CURRENT), "Leaf": (2015, CURRENT)},
        "Hyundai": {"Elantra": (2010, CURRENT), "Sonata": (2012, CURRENT), "Tucson": (2015, CURRENT), "Santa Fe": (2013, CURRENT)},
        "Kia": {"Sorento": (2012, CURRENT), "Sportage": (2010, CURRENT), "Forte": (2013, CURRENT), "Telluride": (2020, CURRENT)},
        "Volkswagen": {"Jetta": (2010, CURRENT), "Passat": (2012, CURRENT), "Tiguan": (2009, CURRENT), "Atlas": (2018, CURRENT)},
        "Tesla": {"Model S": (2012, CURRENT), "Model 3": (2017, CURRENT), "Model X": (2015, CURRENT), "Model Y": (2020, CURRENT)},
        "Subaru": {"Impreza": (2010, CURRENT), "Outback": (2012, CURRENT), "Forester": (2014, CURRENT), "Crosstrek": (2013, CURRENT)}
    }

    vehicles = []
    makes = list(vehicle_catalog.keys())

    for v in range(1, num_vehicles + 1):
        make = random.choice(makes)
        model, year_range = random.choice(list(vehicle_catalog[make].items()))
        year = random.randint(*year_range)
        vehicles.append(
            [
                str(v),
                make,
                model,
                str(year),
                self.fake.safe_color_name(),
                self.fake.vin(),
                self.fake.license_plate(),
                self.fake.state_abbr()
            ]
        )

    values_string = ','.join('(' + ','.join('"' + s + '"' for s in v) + ')' for v in vehicles)
    spark.sql(f'INSERT INTO {self.vehicle_dim} VALUES {values_string}')

# COMMAND ----------

import datetime
import random

@DBAcademyHelper.add_init
def init_officer_dim(self):
    self.officer_dim = f"{self.catalog_name}.{self.schema_name}.officer_dim"

    if self.table(self.officer_dim):
      return

    print(f"Initializating new table {self.officer_dim}")

    self.new_dims = True
    num_officers = 10

    spark.sql(f"""
              CREATE OR REPLACE TABLE {self.officer_dim}
              ( officer_id STRING,
                badge STRING,
                name STRING,
                rank STRING,
                precinct STRING,
                doh DATE,
                active BOOLEAN,
                CONSTRAINT officer_pk PRIMARY KEY (officer_id)
              )""")

    ranks = ["Officer", "Detective", "Corporal", "Sergeant", "Lieutenant", "Captain"]
    precincts = ["North Division", "Central Division", "East Side", "West End", "South Patrol"]

    officers = [
        [
            str(i),
            self.fake.bothify(text="#######"),
            f'{self.fake.last_name()}, {self.fake.first_name()}',
            random.choice(ranks),
            random.choice(precincts),
            self.fake.date_of_birth(minimum_age=1, maximum_age=45).strftime("%Y-%m-%d"),
            str(random.choice([True,True,True,True,False]))
        ] for i in range(1, num_officers + 1)
    ]

    values_string = ','.join('(' + ','.join('"' + s + '"' for s in o) + ')' for o in officers)
    spark.sql(f'INSERT INTO {self.officer_dim} VALUES {values_string}')

# COMMAND ----------

import datetime
import random

@DBAcademyHelper.add_init
def init_traffic_facts(self):
    self.traffic_facts = f"{self.catalog_name}.{self.schema_name}.traffic_events"
    self.event_types = [
        "Civil Traffic Violation",
        "Criminal Traffic Violation",
        "License Check",
        "Stolen Vehicle Report",
        "Expired Registration", 
        "Equipment Deficiency",
        "Parking Violation"
    ]

    if self.table(self.traffic_facts) and not self.new_dims:
      return

    print(f"Initializating new table {self.traffic_facts}")

    num_events = 500

    spark.sql(f"""
              CREATE OR REPLACE TABLE {self.traffic_facts}
              ( event_id STRING,
                officer_id STRING,
                driver_id STRING,
                vehicle_id STRING,
                event_type STRING,
                event_time TIMESTAMP,
                location STRING,
                CONSTRAINT event_pk PRIMARY KEY (event_id),
                CONSTRAINT event_fk_officer FOREIGN KEY (officer_id) REFERENCES {self.officer_dim},
                CONSTRAINT event_fk_driver FOREIGN KEY (driver_id) REFERENCES {self.driver_dim},
                CONSTRAINT event_fk_vehicle FOREIGN KEY (vehicle_id) REFERENCES {self.vehicle_dim}
              )""")

    vehicle_ids = [row[0] for row in spark.sql(f'SELECT vehicle_id from {self.vehicle_dim}').collect()]
    driver_ids = [row[0] for row in spark.sql(f'SELECT driver_id from {self.driver_dim}').collect()]
    officer_ids = [row[0] for row in spark.sql(f'SELECT officer_id from {self.officer_dim}').collect()]

    events = [
        [
            str(i) + ('C' if random.random() < 0.05 else ''),
            str(random.choice(officer_ids)),
            str(random.choice(driver_ids)),
            str(random.choice(vehicle_ids)),
            random.choice(self.event_types),
            self.fake.date_time_between(start_date='-2y', end_date='-1d').strftime("%Y-%m-%d %H:%M:%S"),
            self.fake.street_name()
        ] for i in range(1, num_events + 1)
    ]

    values_string = ','.join('(' + ','.join('"' + s + '"' for s in e) + ')' for e in events)
    spark.sql(f'INSERT INTO {self.traffic_facts} VALUES {values_string}')

# COMMAND ----------

import random

@DBAcademyHelper.add_method
def setup_sql_parms(self):
    dbutils.widgets.removeAll()

    drivers = [row[0] for row in spark.sql(f'SELECT name from {self.driver_dim} ORDER BY name').collect()]

    dbutils.widgets.dropdown("driver", random.choice(drivers), drivers)
    dbutils.widgets.dropdown("event_type", self.event_types[0], self.event_types)

# COMMAND ----------

@DBAcademyHelper.add_init
def display_dataset_link(self):
    displayHTML(f"""
                Catalog: <i>{DA.catalog_name}</i><br/>
                Schema: <i>{DA.schema_name}</i><br/>
                <a href="explore/data/{DA.catalog_name}/{DA.schema_name}" target="_blank">Explore your schema</a> (opens in new tab)
                """)

# COMMAND ----------

DA = DBAcademyHelper()
DA.init()