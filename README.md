# Demo of CockroachDB, OpenShift, and Cloudera within the context of clinical medical data

## Overview

* Patient sees a medical provider
* Medical provider enters patient biometric data into clinical app
* CockroachDB is the OLTP database for the clinical app
* A CockroachDB changefeed (CDC) is configured to publish to a Kafka topic
* Cloudera consumes from the Kafka topic and then
  - predicts if the patient is at high risk for heart failure
  - creates a visualization of the data

## Deploying and running the demo

* The [./k8s/deploy_demo.sh](./k8s/deploy_demo.sh) script can be used to roll this out, or as a guide.
* Note that CockroachDB changefeeds require an enterprise license.
* The [./k8s/db_cli.sh](./k8s/db_cli.sh) script will run a `cockroach sql` client and connect to the DB
(requires the [`cockroach` binary](https://www.cockroachlabs.com/docs/releases/index.html) installed locally).
Alternatively, if you have `psql` installed, you could use [./k8s/psql_cli.sh](./k8s/psql_cli.sh).

## Data

* Initial state: CSV

[Here's a copy of the CSV](./heart_failure_clinical_records_dataset.csv)

```
age,anaemia,creatinine_phosphokinase,diabetes,ejection_fraction,high_blood_pressure,platelets,serum_creatinine,serum_sodium,sex,smoking,time,DEATH_EVENT
75,0,582,0,20,1,265000,1.9,130,1,0,4,1
55,0,7861,0,38,0,263358.03,1.1,136,1,0,6,1
```

* In the database:
```
defaultdb=> select * from clinical order by random() limit 1;
-[ RECORD 1 ]------------------+-------------------------------------
patient_id                     | 1362bbbe-f62f-4367-9c73-1fead17da9cb
ts                             | 2022-08-11 12:20:53.920564
age                            | 41
anaemia                        | f
serum_creatinine_phosphokinase | 321.2
diabetes                       | t
ejection_fraction              | 29.75
high_blood_pressure            | f
platelets                      | 892668
serum_creatinine               | 1.105
serum_sodium                   | 155.7
sex                            | F
smoking                        | t
time                           | 98
```

* From the Kafka topic: see below

## Consume messages from the Kafka topic

* Use your preferred client
* For the current configuration, the broker endpoint is `cockroach-cluster-kafka-brokers.kafka.svc.cluster.local:9092`
* Example:
```
oc run kafka-consumer -ti --image=registry.redhat.io/amq7/amq-streams-kafka-31-rhel8:2.1.0 \
  --rm=true --restart=Never -- bin/kafka-console-consumer.sh \
  --bootstrap-server cockroach-cluster-kafka-brokers.kafka.svc.cluster.local:9092 \
  --topic clinical --max-messages 10
```

## Rebuild and publish Docker image of the workload script

* Edit [docker_include.sh](./docker_include.sh) as necessary (increment tag, etc.)
* Run: `$ ./docker_build_image.sh && ./docker_tag_publish.sh`
* Revise [k8s/workload.yaml](./k8s/workload.yaml) as necessary to align with tags, etc.

## References

* [Data source](https://archive.ics.uci.edu/ml/datasets/Heart+failure+clinical+records)
* [Deploy CockroachDB on K8s](https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-kubernetes.html)
* [CockroachDB changefeeds](https://www.cockroachlabs.com/docs/v22.1/create-changefeed)

