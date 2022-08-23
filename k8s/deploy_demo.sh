#!/bin/bash

# https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-kubernetes.html

if [ -z "${CRDB_LICENSE}" ]
then
  cat <<EoM

  Prior to running $0, you need to set the CRDB_LICENSE variable

  EXAMPLE:

  $ export CRDB_LICENSE="SET CLUSTER SETTING cluster.organization = 'My Demo';
  SET CLUSTER SETTING enterprise.license = 'crl-0-AVcqn9lAMAIuqBPBUE8gRGSowa';"

  NOTE:
  
  This is the CockroachDB demo license you obtained from Cockroach Labs

EoM
  exit 1
fi

dir=$( dirname $0 )
. $dir/include.sh

# Get OpenShift CLI credentials from here:
# https://oauth-openshift.apps.cluster-qux29.qux29.sandbox8125.opentlc.com/oauth/token/display

# Log into OpenShift (credential values shown here aren't real)
oc login --insecure-skip-tls-verify=true --token=sha256~amVuWiHi2niARipPSXx20ghQ2QKA1IC7gfqQQ3Kd0J9 --server=https://api.cluster-qux29.qdx57.sandbox8125.opentlc.com:6443

# Create the CockroachDB cluster
echo "See https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-kubernetes.html"
echo "Apply the CustomResourceDefinition (CRD) for the Operator"
run_cmd kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/v2.6.0/install/crds.yaml

echo "Apply the Operator manifest"
OPERATOR_YAML="https://raw.githubusercontent.com/cockroachdb/cockroach-operator/v2.6.0/install/operator.yaml"
run_cmd kubectl apply -f $OPERATOR_YAML

echo "Setting default namespace to the operator namespace"
run_cmd kubectl config set-context --current --namespace=cockroach-operator-system

echo "Validate that the Operator is running"
run_cmd kubectl get pods

echo "Initialize the cluster"
run_cmd kubectl apply -f ./cockroachdb.yaml

echo "Check that the pods were created"
run_cmd kubectl get pods

echo "WAIT until the output of 'kubectl get pods' shows the three cockroachdb-N nodes in 'Running' state"
echo "(This could take 5 minutes)"
run_cmd kubectl get pods

echo "Check to see whether the LB for DB Console and SQL is ready yet"
echo "Look for the external IP of the app in the 'LoadBalancer Ingress:' line of output"
run_cmd kubectl describe service crdb-lb
echo "If not, run 'kubectl describe service crdb-lb' in a separate window"

SQL_CLIENT_YAML="https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/examples/client-secure-operator.yaml"
echo "Adding a secure SQL client pod ..."
kubectl create -f $SQL_CLIENT_YAML
echo "Done"

echo "Verify the 'cockroachdb-client-secure' is in 'Running' state"
kubectl get pods
sleep 10
kubectl get pods

# Add DB user for app
echo "Once all three DB pods show 'Running', use the SQL CLI to add a user for use by the Web app"
echo "Press ENTER to run this SQL"
read
cat ./create_user.sql | kubectl exec -i cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public
echo "User 'demouser' with password 'demopasswd' has been added."

echo "Start the workload (doing the INSERTs of the medical data)"
run_cmd kubectl apply -f ./workload.yaml
run_cmd kubectl get pods

# Start the CockroachDB DB Console
echo "Open a browser tab to port 8080 at the IP provided for the DB Console endpoint"
echo
echo "** Use 'demouser' as login and 'demopasswd' as password **"

echo "Apply the CockroachDB Enterprise license"
echo "Press ENTER when that's done"
read
echo "$CRDB_LICENSE" | kubectl exec -i cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public

echo "Ensure the AMQStreams Kafka instance is configured and running on OpenShift"
echo "The name of that needs to be 'cockroach-cluster' (this is baked into the demo)"
echo "Press ENTER to proceed"
read

echo "Create the Kafka topic 'clinical' to match the name of the table in the DB:"
run_cmd kubectl apply -f ./kafka-create-topic.yaml

echo "Start the changefeed (CDC) on the CockroachDB cluster:"
cat ./create_changefeed.sql | kubectl exec -i cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public

sleep 10
echo "Press ENTER to consume 10 rows from the Kafka topic:"
read
oc run kafka-consumer -ti --image=registry.redhat.io/amq7/amq-streams-kafka-31-rhel8:2.1.0 \
  --rm=true --restart=Never -- bin/kafka-console-consumer.sh \
  --bootstrap-server cockroach-cluster-kafka-brokers.kafka.svc.cluster.local:9092 \
  --topic clinical --max-messages 10

# Kill a node
echo "Kill a CockroachDB pod"
run_cmd kubectl delete pods cockroachdb-0
echo "Reload the app page to verify it continues to run"
echo "Also, note the state in the DB Console"
echo "A new pod should be started to replace the failed pod"
run_cmd kubectl get pods

# Perform an online rolling upgrade
echo "Perform a zero downtime upgrade of CockroachDB (note the version in the DB Console UI)"
run_cmd kubectl apply -f ./rolling_upgrade.yaml
echo "Check the DB Console to verify the version has changed"
echo

# Tear it down
echo
echo
echo "** Finally: tear it all down.  CAREFUL -- BE SURE YOU'RE DONE! **"
echo "Press ENTER to confirm you want to TEAR IT DOWN."
read

echo "Deleting the workload app"
kubectl delete -f ./workload.yaml

echo "Deleting the SQL client"
kubectl delete -f $SQL_CLIENT_YAML

echo "Deleting the CockroachDB cluster"
kubectl delete -f ./cockroachdb.yaml

echo "Deleting the persistent volumes and persistent volume claims"
kubectl delete pv,pvc --all

echo "Deleting the K8s operator"
kubectl delete -f $OPERATOR_YAML

