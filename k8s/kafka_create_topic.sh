#!/bin/bash

topic="clinical"
broker="redpanda-kafka.cockroach-operator-system.svc.cluster.local:9092"

kubectl run -ti --rm --restart=Never --image docker.redpanda.com/vectorized/redpanda -- rpk --brokers $broker topic create $topic -p 5

