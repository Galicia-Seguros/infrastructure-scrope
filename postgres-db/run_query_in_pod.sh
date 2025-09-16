#!/bin/bash

# Function to run PostgreSQL queries using Bitnami PostgreSQL client pod
# Usage: run_query_in_pod <hostname> <port> <dbname> <username> <password> <query> [query_type]
# query_type: "ddl" or "dml" (default: "dml")

set -e
HOSTNAME=$1
PORT=$2
DBNAME=$3
USERNAME=$4
PASSWORD=$5
QUERY=$6
QUERY_TYPE=${7:-"dml"}
QUERY_OUTPUT_FILE=$8
if [ -z "$HOSTNAME" ] || [ -z "$PORT" ] || [ -z "$DBNAME" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$QUERY" ]; then
    echo "Usage: run_query_in_pod <hostname> <port> <dbname> <username> <password> <query> [query_type]"
    exit 1
fi

# Generate unique names
TIMESTAMP=$(date +%s)
RANDOM_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-8)
POD_NAME="psql-client-${TIMESTAMP}-${RANDOM_ID}"
SECRET_NAME="psql-client-secret-${TIMESTAMP}-${RANDOM_ID}"
CONFIGMAP_NAME="psql-client-query-${TIMESTAMP}-${RANDOM_ID}"

# Clean up function (only deletes secret and configmap, leaves pod for debugging on failure)
cleanup() {
    kubectl delete pod $POD_NAME  -n postgres-db --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret $SECRET_NAME -n postgres-db --ignore-not-found=true 2>/dev/null || true
    kubectl delete configmap $CONFIGMAP_NAME -n postgres-db --ignore-not-found=true 2>/dev/null || true
    rm -f /tmp/${POD_NAME}-pod.yaml 2>/dev/null || true
    rm -f /tmp/${POD_NAME}-query.sql 2>/dev/null || true
}
trap cleanup EXIT

# Create temporary SQL file
SQL_FILE="/tmp/${POD_NAME}-query.sql"
echo "$QUERY" > "$SQL_FILE"

# Create ConfigMap with the SQL query
echo "Creating ConfigMap with SQL query..."
kubectl create configmap $CONFIGMAP_NAME -n postgres-db --from-file=query.sql="$SQL_FILE"

# Create secret with database credentials
echo "Creating Secret with database credentials..."
kubectl create secret generic $SECRET_NAME -n postgres-db \
    --from-literal=hostname="$HOSTNAME" \
    --from-literal=port="$PORT" \
    --from-literal=dbname="$DBNAME" \
    --from-literal=username="$USERNAME" \
    --from-literal=password="$PASSWORD"

# Prepare psql command flags based on query type
if [ "$QUERY_TYPE" = "dml" ]; then
    PSQL_FLAGS="-t -A -F','"
else
    PSQL_FLAGS=""
fi

# Create pod YAML manifest
cat > /tmp/${POD_NAME}-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: postgres-db
spec:
  restartPolicy: Never
  containers:
  - name: psql-client
    image: bitnami/postgresql:latest
    command: ["/bin/bash", "-c"]
    args: 
    - |
      PGPASSWORD="\$DB_PASSWORD" psql -h "\$DB_HOSTNAME" -p "\$DB_PORT" -U "\$DB_USERNAME" -d "\$DB_DBNAME" $PSQL_FLAGS -f /sql/query.sql
    env:
    - name: DB_HOSTNAME
      valueFrom:
        secretKeyRef:
          name: $SECRET_NAME
          key: hostname
    - name: DB_PORT
      valueFrom:
        secretKeyRef:
          name: $SECRET_NAME
          key: port
    - name: DB_DBNAME
      valueFrom:
        secretKeyRef:
          name: $SECRET_NAME
          key: dbname
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: $SECRET_NAME
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: $SECRET_NAME
          key: password
    volumeMounts:
    - name: sql-query
      mountPath: /sql
      readOnly: true
  volumes:
  - name: sql-query
    configMap:
      name: $CONFIGMAP_NAME
EOF

# Apply the pod manifest
echo "Creating pod $POD_NAME..."
kubectl apply -f /tmp/${POD_NAME}-pod.yaml

POD_STATUS=$(kubectl get pod $POD_NAME -n postgres-db -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
MAX_RETRIES=30
RETRY_COUNT=0
while [[ "$POD_STATUS" == "Pending" || "$POD_STATUS" == "ContainerCreating" || "$POD_STATUS" == "Running" ]] && [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    echo "Pod is still pending or creating, waiting..."
    sleep 5
    POD_STATUS=$(kubectl get pod $POD_NAME -n postgres-db -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    ((++RETRY_COUNT)) || true
done
echo "Pod status: $POD_STATUS"

# Show logs
echo "Pod logs:"
export QUERY_LOGS=$(kubectl logs $POD_NAME -n postgres-db --follow || true)

# Check final status


if [[ "$QUERY_OUTPUT_FILE" != "" ]]; then
    echo $QUERY_LOGS > $QUERY_OUTPUT_FILE
fi




if [ "$POD_STATUS" = "Succeeded" ]; then
    exit 0
else
    echo "Query execution failed or pod did not complete successfully."
    exit 1;
fi