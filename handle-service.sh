#!/bin/bash
# Set working directory to the script's location

WORKING_DIRECTORY="$(dirname "$(realpath "$0")")"
cd "$WORKING_DIRECTORY" || exit 1

source ./process-notification.sh
# Source yaml utility functions
source ./yaml.sh
# Source json utility functions
source ./json.sh

# Load environment variables if the file exists
[ -f env ] && source env

# Capture the first argument as NP_ACTION_CONTEXT
export NP_ACTION_CONTEXT=$1
echo "📩 Notification received: $NP_ACTION_CONTEXT"
export JSON_PAYLOAD=$(read_json_input $NP_ACTION_CONTEXT 2>/dev/null || true)
parse_notification $JSON_PAYLOAD

echo "      🏷️ Service type: $SERVICE_TYPE"

# Execute the Null Platform service action
echo "🚀 Executing nullplatform service action..."

echo "Running opentofu service"
./do_opentofu.sh
exit $?

#np service-action exec --live-output --live-report --debug
