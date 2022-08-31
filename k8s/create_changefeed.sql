SET CLUSTER SETTING kv.rangefeed.enabled = true;
CREATE CHANGEFEED FOR TABLE clinical INTO 'kafka://cockroachcluster-kafka-brokers.openshift-operators.svc.cluster.local:9092' WITH envelope = 'row';
