#!/bin/bash

topic="clinical"
n_rows=1
broker="redpanda-kafka.cockroach-operator-system.svc.cluster.local:9092"

kubectl run -ti --rm --restart=Never --image docker.redpanda.com/vectorized/redpanda -- rpk topic consume -n $n_rows $topic --brokers $broker

