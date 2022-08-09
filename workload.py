#!/usr/bin/env python3

"""

DEPENDENCIES:

  $ sudo apt install python3-pip
  $ pip3 install psycopg2-binary

RUN:

  $ export DB_URL="postgres://root@localhost:26257/defaultdb"
  $ export T_SLEEP_MS=100

REF:

  https://archive.ics.uci.edu/ml/datasets/Heart+failure+clinical+records

"""

import time
import random
import logging
import os, sys
import psycopg2
from psycopg2.errors import SerializationFailure
import csv
import requests

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(message)s", datefmt="%m/%d/%Y %I:%M:%S %p")

# How to connect to CockroachDB; e.g. "postgres://root@localhost:26257/defaultdb"
db_url = os.getenv("DB_URL")
if db_url is None:
  print("Environment DB_URL must be set. Quitting.")
  sys.exit(1)
logging.info("DB_URL: {}".format(db_url))

# Time to sleep between INSERTs
t_sleep_s = int(os.getenv("T_SLEEP_MS", "100"))/1.0E+03
logging.info("T_SLEEP_MS: {}".format(t_sleep_s * 1.0E+03))

# The continuous values in the CSV will be "perturbed" by this much
perturb = float(os.getenv("PERTURB_FRACTION", "0.15"))
logging.info("PERTURB_FRACTION: {}".format(perturb))

# The source of the CSV data
CSV_URL = os.getenv("CSV_URL",
  "https://archive.ics.uci.edu/ml/machine-learning-databases/00519/heart_failure_clinical_records_dataset.csv")

def do_setup(conn):
  with conn.cursor() as cur:
    cur.execute("CREATE TYPE IF NOT EXISTS mf AS ENUM ('M', 'F');")
    logging.info("%s", cur.statusmessage)
    cur.execute("DROP TABLE IF EXISTS clinical;")
    logging.info("%s", cur.statusmessage)
    sql = """
    CREATE TABLE clinical
    (
      patient_id UUID NOT NULL DEFAULT gen_random_uuid()
      , ts TIMESTAMP NOT NULL DEFAULT now()
      , age INT
      , anaemia BOOL
      , serum_creatinine_phosphokinase FLOAT
      , diabetes BOOL
      , ejection_fraction FLOAT
      , high_blood_pressure BOOL
      , platelets FLOAT
      , serum_creatinine FLOAT
      , serum_sodium FLOAT
      , sex MF
      , smoking BOOL
      , time INT
      , PRIMARY KEY (patient_id, ts)
    );
  """
    cur.execute(sql)
    logging.info("%s", cur.statusmessage)
  conn.commit()

def perturb_float(v):
  v = float(v)
  return float(v - v * perturb + random.randint(0, int(2 * perturb * v)))

def perturb_int(v):
  v = int(v)
  return int(v - v * perturb + random.randint(0, int(2 * perturb * v)))

csv_data = None
def gen_row():
  row = csv_data[random.randint(0, len(csv_data) - 1)]
  row = [float(x) for x in row]
  row[0] = perturb_int(row[0]) # age
  row[1] = int(row[1]) # anaemia
  row[2] = perturb_float(row[2]) # serum_creatinine_phosphokinase
  row[3] = int(row[3]) # diabetes
  row[4] = perturb_float(row[4]) # ejection_fraction
  row[5] = int(row[5]) # high_blood_pressure
  row[6] = perturb_float(row[6]) # platelets
  row[7] = perturb_float(row[7]) # serum_creatinine
  row[8] = perturb_float(row[8]) # serum_sodium
  row[9] = 'F' if row[9] == 1 else 'M' # sex
  row[10] = int(row[10]) # smoking
  row[11] = perturb_int(row[11]) # days
  return tuple(row[0:12]) # Removing last column which is the predicted one

def get_csv():
  rv = None
  with requests.Session() as s:
    download = s.get(CSV_URL)
    decoded_content = download.content.decode("utf-8")
    cr = csv.reader(decoded_content.splitlines(), delimiter=',')
    rv = [list(x) for x in list(cr)]
  return rv[1:] # Strip header row

"""
  Execute the operation op(conn), retrying serialization failure.
  If the database returns an error asking to retry the transaction, retry it
  max_retries times before giving up (and propagate it).
"""
def run_transaction(conn, op, max_retries=3):
  # leaving this block the transaction will commit or rollback
  # (if leaving with an exception)
  with conn:
    for retry in range(1, max_retries + 1):
      try:
        op(conn)
        # If we reach this point, we were able to commit, so we break
        # from the retry loop.
        return
      except SerializationFailure as e:
        # This is a retry error, so we roll back the current
        # transaction and sleep for a bit before retrying. The
        # sleep time increases for each failed transaction.
        logging.debug("Error: %s", e)
        conn.rollback()
        logging.debug("EXECUTE SERIALIZATION_FAILURE BRANCH")
        sleep_ms = (2**retry) * 0.1 * (random.random() + 0.5)
        logging.debug("Sleeping %s ms", sleep_ms)
        time.sleep(sleep_ms)
      except psycopg2.Error as e:
        logging.debug("Error: %s", e)
        logging.debug("EXECUTE NON-SERIALIZATION_FAILURE BRANCH")
        raise e
    raise ValueError(f"transaction did not succeed after {max_retries} retries")

insert_sql = """
INSERT INTO clinical
(age, anaemia, serum_creatinine_phosphokinase, diabetes, ejection_fraction, high_blood_pressure,
platelets, serum_creatinine, serum_sodium, sex, smoking, time) 
 
VALUES (%s, CAST(%s AS BOOL), %s, CAST(%s AS BOOL), %s, CAST(%s AS BOOL), %s, %s, %s, %s, CAST(%s AS BOOL), %s);
"""

def do_insert(conn, sql, row):
  with conn.cursor() as cur:
    cur.execute(sql, row)
  conn.commit()
  logging.debug("do_insert(): %s", cur.statusmessage)

# main()
conn = None
try:
  conn = psycopg2.connect(db_url, application_name="clinical data")
except Exception as e:
  logging.fatal("database connection failed")
  logging.fatal(e)

do_setup(conn)
csv_data = get_csv()

n_rows = 0
while (True):
  run_transaction(conn, lambda conn: do_insert(conn, insert_sql, gen_row()))
  n_rows += 1
  if n_rows % 25 == 0:
    logging.info("Rows inserted: %s", n_rows)
  time.sleep(t_sleep_s)

conn.close()

