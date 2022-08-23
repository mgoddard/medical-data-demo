SET CLUSTER SETTING kv.rangefeed.enabled = true;
CREATE CHANGEFEED FOR TABLE clinical INTO 'kafka://cockroach-cluster-kafka-brokers.kafka.svc.cluster.local:9092' WITH envelope = 'row';
