#!/bin/bash

# https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-kubernetes.html

REGION="us-east4"
MACHINETYPE="e2-standard-4" # 4	vCPU, 16 GB RAM, $0.134012/hour
N_NODES=2 # This will create N_NODES *per AZ* within REGION

NAME="${USER}-medical-demo"

dir=$( dirname $0 )
. $dir/include.sh

# Create the GKE K8s cluster
echo "See https://www.cockroachlabs.com/docs/v21.1/orchestrate-cockroachdb-with-kubernetes.html#hosted-gke"
run_cmd gcloud container clusters create $NAME --region=$REGION --machine-type=$MACHINETYPE --num-nodes=$N_NODES
if [ "$y_n" = "y" ] || [ "$y_n" = "Y" ]
then
  ACCOUNT=$( gcloud info | perl -ne 'print "$1\n" if /^Account: \[([^@]+@[^\]]+)\]$/' )
  kubectl create clusterrolebinding $USER-cluster-admin-binding --clusterrole=cluster-admin --user=$ACCOUNT
fi

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


echo "Start the workload (doing the INSERTs of the medical data)"
run_cmd kubectl apply -f ./workload.yaml
run_cmd kubectl get pods

# Start the CockroachDB DB Console
echo "Open a browser tab to port 8080 at the IP provided for the DB Console endpoint"
echo
echo "** Use 'demouser' as login and 'demopasswd' as password **"

# Install Redpanda Kafka (https://docs.redpanda.com/docs/quickstart/kubernetes-qs-cloud/)
echo "Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io && helm repo update && helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.4.4 --set installCRDs=true

sleep 5
echo "Verify there are 3 'cert-manager-...' pods running"
kubectl get pods --namespace cert-manager
echo "If not, re-run 'kubectl get pods --namespace cert-manager' again and don't proceed until they are running"

echo "Add Redpanda chart repository"
helm repo add redpanda https://charts.vectorized.io/ && helm repo update

export VERSION=$(curl -s https://api.github.com/repos/redpanda-data/redpanda/releases/latest | jq -r .tag_name)

echo "Apply the Redpanda CRD"
kubectl apply -k https://github.com/redpanda-data/redpanda/src/go/k8s/config/crd?ref=$VERSION

echo "Install the Redpanda operator"
helm install redpanda-operator redpanda/redpanda-operator --namespace redpanda-system --create-namespace --version $VERSION

kubectl -n redpanda-system rollout status -w deployment/redpanda-operator
echo "If the output says 'deployment \"redpanda-operator\" successfully rolled out', you can run the next step."

echo "Deploy the Redpanda instance"
run_cmd kubectl apply -f ./redpanda.yaml
sleep 10
kubectl get pods

echo "Ensure the 'redpanda-kafka-0' pod show a 'Running' state before running the next step."
run_cmd ./kafka_create_topic.sh

echo "Start the changefeed (CDC) on the CockroachDB cluster:"
cat ./create_changefeed.sql | kubectl exec -i cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public

sleep 10
echo "Consume one row from the Kafka topic:"
run_cmd ./kafka_consume_topic.sh

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

echo "Deleting Kafka"
kubectl delete -f ./redpanda.yaml

echo "Deleting the SQL client"
kubectl delete -f $SQL_CLIENT_YAML

echo "Deleting the CockroachDB cluster"
kubectl delete -f ./cockroachdb.yaml

echo "Deleting the persistent volumes and persistent volume claims"
kubectl delete pv,pvc --all

echo "Deleting the K8s operator"
kubectl delete -f $OPERATOR_YAML

echo "Deleting the GKE cluster"
run_cmd gcloud container clusters delete $NAME --region=$REGION --quiet

