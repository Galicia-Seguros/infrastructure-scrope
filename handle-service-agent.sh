#!/bin/bash -x

WORKING_DIRECTORY="$(dirname "$(realpath "$0")")"
cd "$WORKING_DIRECTORY" || exit 1

source ./process-notification.sh

echo "Starting handle agent service"
if [[ "$NP_ACTION_CONTEXT" == "" ]]; then
    export NP_ACTION_CONTEXT=$1
fi

echo "📩 Notification received: $NP_ACTION_CONTEXT"
export JSON_PAYLOAD=$(read_json_input $NP_ACTION_CONTEXT 2>/dev/null || true)
parse_notification $JSON_PAYLOAD

if [[ "$SERVICE_SPECIFICATION_SLUG" == "mcp" || "$SERVICE_SPECIFICATION_SLUG" == "mcp-server" ]]; then
    echo "MCP Service detected: $SERVICE_SPECIFICATION_SLUG"
    np service-action exec --live-output --live-report --debug
    exit $?
fi

check_service_slug() {
    case "$SERVICE_SPECIFICATION_SLUG" in
        "api-gtw-ex"|"serverless-valkey"|"sqs-queue"|"sqs-queue-without-actions")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if [[ "$ACTION_TYPE" == "custom" || "$IS_SCOPE" != "" ]] || check_service_slug; then
    echo "Action Type [$ACTION_TYPE] SERVICE_SPECIFICATION_SLUG [$SERVICE_SPECIFICATION_SLUG]"
    np service-action exec --live-output --live-report --debug --script "do_opentofu.sh"
    exit $?
fi

np service-action exec --live-output --live-report --debug 
exit $?