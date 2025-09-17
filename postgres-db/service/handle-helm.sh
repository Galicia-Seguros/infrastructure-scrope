#!/bin/bash
export WORKING_DIRECTORY_ORIGINAL="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $WORKING_DIRECTORY_ORIGINAL

source ./project.sh

# Add Bitnami Helm repo if not already added
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo update

# Get parameters
USAGE_TYPE=$ACTION_PARAMETERS_USAGE_TYPE
PII_ENABLED=${ACTION_PARAMETERS_PII:-false}
DB_NAME="${USAGE_TYPE:-app}_db"

# Generate random password for PostgreSQL superuser
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Create Kubernetes secret for PostgreSQL credentials
kubectl create namespace postgres-db --dry-run=client -o yaml | kubectl apply -f -

# Create secret with database credentials
kubectl create secret generic $PROJECT-postgres-credentials \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=username=postgres \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --from-literal=database="$DB_NAME" \
  -n postgres-db \
  --dry-run=client -o yaml | kubectl apply -f -

echo '{"projectName":"'"$PROJECT"'","usageType":"'"$USAGE_TYPE"'","piiEnabled":'"$PII_ENABLED"',"dbName":"'"$DB_NAME"'","postgresPassword":"'"$POSTGRES_PASSWORD"'"}' > /tmp/context-$PROJECT.json

gomplate \
  --context .=/tmp/context-$PROJECT.json \
  -f values.yaml.tpl > /tmp/values-$PROJECT.yaml

# Install using Bitnami PostgreSQL chart
helm upgrade --install -n postgres-db $PROJECT-postgres bitnami/postgresql -f /tmp/values-$PROJECT.yaml --create-namespace > /dev/null