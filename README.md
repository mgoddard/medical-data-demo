# Demo of CockroachDB, OpenShift, and Cloudera within the context of clinical medical data

## Overview

* Patient sees a medical provider
* Medical provider collects information/data from the patient
* Patient data is loaded to CockroachDB
* Data gets published to a Kafka topic
* Cloudera consumes from the Kafka topic and
  - predicts if the patient is at high risk for heart failure
  - and creates a visualization of the data

## Consuming messages from the Kafka topic

```
$ ./kafka_consume_topic.sh 
+ /usr/local/bin/supervisord -d
+ '[' '' = true ']'
+ exec /usr/bin/rpk topic consume --format json -n 5 clinical --brokers one-node-cluster-0.one-node-cluster.cockroach-operator-system.svc.cluster.local:9092
{
  "topic": "clinical",
  "key": "[\"00009272-1fe2-41b8-86a7-b27c16fc5414\", \"2022-08-09T20:08:46.572149\"]",
  "value": "{\"after\": {\"age\": 77, \"anaemia\": false, \"diabetes\": true, \"ejection_fraction\": 37.75, \"high_blood_pressure\": false, \"patient_id\": \"00009272-1fe2-41b8-86a7-b27c16fc5414\", \"platelets\": 254548, \"serum_creatinine\": 2.975, \"serum_creatinine_phosphokinase\": 648.7, \"serum_sodium\": 125.9, \"sex\": \"F\", \"smoking\": false, \"time\": 33, \"ts\": \"2022-08-09T20:08:46.572149\"}}",
  "timestamp": 1660097103186,
  "partition": 2,
  "offset": 0
}
{
  "topic": "clinical",
  "key": "[\"00027e74-4f11-4153-9f58-44c92fa38044\", \"2022-08-10T01:13:03.342865\"]",
  "value": "{\"after\": {\"age\": 45, \"anaemia\": true, \"diabetes\": false, \"ejection_fraction\": 29.75, \"high_blood_pressure\": false, \"patient_id\": \"00027e74-4f11-4153-9f58-44c92fa38044\", \"platelets\": 2.8764E+5, \"serum_creatinine\": 0.765, \"serum_creatinine_phosphokinase\": 146.65, \"serum_sodium\": 145.45, \"sex\": \"F\", \"smoking\": false, \"time\": 207, \"ts\": \"2022-08-10T01:13:03.342865\"}}",
  "timestamp": 1660097103186,
  "partition": 2,
  "offset": 1
}
{
  "topic": "clinical",
  "key": "[\"000648c0-32e9-40eb-8324-0a6fcea37125\", \"2022-08-09T22:22:42.317985\"]",
  "value": "{\"after\": {\"age\": 68, \"anaemia\": true, \"diabetes\": true, \"ejection_fraction\": 33.5, \"high_blood_pressure\": true, \"patient_id\": \"000648c0-32e9-40eb-8324-0a6fcea37125\", \"platelets\": 259995, \"serum_creatinine\": 1.36, \"serum_creatinine_phosphokinase\": 128.8, \"serum_sodium\": 121.6, \"sex\": \"M\", \"smoking\": false, \"time\": 22, \"ts\": \"2022-08-09T22:22:42.317985\"}}",
  "timestamp": 1660097103186,
  "partition": 2,
  "offset": 2
}
{
  "topic": "clinical",
  "key": "[\"00081432-dcfd-4916-b0fc-129dd3da6150\", \"2022-08-10T01:37:56.664282\"]",
  "value": "{\"after\": {\"age\": 77, \"anaemia\": false, \"diabetes\": false, \"ejection_fraction\": 17, \"high_blood_pressure\": true, \"patient_id\": \"00081432-dcfd-4916-b0fc-129dd3da6150\", \"platelets\": 292557.32550000004, \"serum_creatinine\": 1.5555, \"serum_creatinine_phosphokinase\": 630.7, \"serum_sodium\": 115.9, \"sex\": \"F\", \"smoking\": true, \"time\": 31, \"ts\": \"2022-08-10T01:37:56.664282\"}}",
  "timestamp": 1660097103186,
  "partition": 2,
  "offset": 3
}
{
  "topic": "clinical",
  "key": "[\"0008b4ad-59d3-44cd-a511-880c8fa23eb7\", \"2022-08-09T23:59:58.1197\"]",
  "value": "{\"after\": {\"age\": 59, \"anaemia\": false, \"diabetes\": true, \"ejection_fraction\": 38.75, \"high_blood_pressure\": false, \"patient_id\": \"0008b4ad-59d3-44cd-a511-880c8fa23eb7\", \"platelets\": 238563.32550000004, \"serum_creatinine\": 0.935, \"serum_creatinine_phosphokinase\": 885.2, \"serum_sodium\": 146.7, \"sex\": \"M\", \"smoking\": false, \"time\": 242, \"ts\": \"2022-08-09T23:59:58.1197\"}}",
  "timestamp": 1660097103186,
  "partition": 2,
  "offset": 4
}
pod "rpk" deleted
```

## References

* [Data source](https://archive.ics.uci.edu/ml/datasets/Heart+failure+clinical+records)
* [Deploy CockroachDB on K8s](https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-kubernetes.html)
* [Redpanda Kafka](https://docs.redpanda.com/docs/quickstart/kubernetes-qs-cloud/)

