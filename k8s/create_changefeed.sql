CREATE CHANGEFEED FOR TABLE clinical INTO 'kafka://redpanda-kafka.cockroach-operator-system.svc.cluster.local:9092' WITH envelope = 'row';
