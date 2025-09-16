#!/bin/bash

# Load json utility functions
json_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$json_script_dir/json.sh"

# Function to read JSON input from a file, stdin, or an environment variable
read_json_input() {
    if [[ -n "$NP_ACTION_CONTEXT" ]]; then
        echo "$NP_ACTION_CONTEXT"
    elif [[ -p /dev/stdin ]]; then
        cat
    elif [[ -n "$1" && -f "$1" ]]; then
        cat "$1"
    else
        echo "Usage:"
        echo "  1️⃣ From a JSON file:"
        echo "       source process-notification.sh && read_json_input <json_file>"
        echo "  2️⃣ From an environment variable (NP_ACTION_CONTEXT):"
        echo "       export NP_ACTION_CONTEXT='{\"notification\": {...}}'"
        echo "       source process-notification.sh && read_json_input"
        echo "  3️⃣ From standard input (stdin):"
        echo "       echo '{\"notification\": {...}}' | source process-notification.sh && read_json_input"
        return 1
    fi
}

# Function to parse notification JSON and export values
parse_notification() {
    # Usage: CMD='echo "{\"hello\":\"world\"}"'
    #        RES=$(build_json_object "$CMD" '.') # jq expression
    local json_payload="$1"

    # Debugging: Print the notification payload
    # echo "🔹 Notification payload: $json_payload"

    export ACTION_TYPE=$(extract_json_field "$json_payload" '.notification.type')
    export ACTION_SLUG=$(extract_json_field "$json_payload" '.notification.action')
    export SERVICE_ID=$(extract_json_field "$json_payload" '.notification.service.id')
    export SERVICE_SLUG=$(extract_json_field "$json_payload" '.notification.service.slug')
    export SERVICE_SPECIFICATION_SLUG=$(extract_json_field "$json_payload" '.notification.service.specification.slug')
    export SERVICE_TYPE=$(extract_json_field "$json_payload" '.notification.service.specification.slug')
    export SERVICE_ATTRIBUTES=$(extract_json_field "$json_payload" '.notification.service.attributes')
    export LINK_ID=$(extract_json_field "$json_payload" '.notification.link.id')
    export LINK_SLUG=$(extract_json_field "$json_payload" '.notification.link.slug')
    export LINK_TYPE=$(extract_json_field "$json_payload" '.notification.link.specification.slug')
    export LINK_ATTRIBUTES=$(extract_json_field "$json_payload" '.notification.link.attributes')
    export NOTIFICATION_ID=$(extract_json_field "$json_payload" '.notification.id')

    AWS_ACCESS_KEY_INTERNAL=$(extract_json_field "$json_payload" '.notification.parameters.access_key_id')
    if [[ "$AWS_ACCESS_KEY_INTERNAL" != "" && "$AWS_ACCESS_KEY_INTERNAL" != "null" ]]; then
        export AWS_REGION=$(extract_json_field "$json_payload" '.notification.parameters.aws_region')
        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_INTERNAL
        export AWS_SECRET_ACCESS_KEY=$(extract_json_field "$json_payload" '.notification.parameters.secret_access_key')    
    fi
    
    export ACTION_CONTEXT_FILE="/tmp/$NOTIFICATION_ID.context.json"
    export ACTION_CONTEXT=$json_payload

    echo $ACTION_CONTEXT > $ACTION_CONTEXT_FILE
    
    IS_LINK=$(extract_json_field "$json_payload" '.notification.link')

    if [[ -z "$IS_LINK" || "$IS_LINK" == "null" ]]; then
        export IS_SERVICE="true"
    else
        export IS_SERVICE="false"
    fi
    

    if [[ -z "$SERVICE_SLUG" || "$SERVICE_SLUG" == "null" ]]; then
        echo "Error: Service slug is missing in the notification payload."
        return 1
    fi

    if [[ -z "$SERVICE_TYPE" || "$SERVICE_TYPE" == "null" ]]; then
        echo "Error: Service type is missing in the notification payload."
        return 1
    fi

    if [[ "$LINK_SLUG" == "null" ]]; then
        LINK_SLUG=""
    fi

    if [[ "$LINK_TYPE" == "null" ]]; then
        LINK_TYPE=""
    fi

    echo "🔔 Parsed Notification:"
    echo "      🆔 Notification ID: ${NOTIFICATION_ID:-"N/A"}"
    echo "      ⚡ Action: $ACTION_TYPE"
    echo "      🔧 Service: $SERVICE_SLUG"
    echo "      🏷️ Service type: $SERVICE_TYPE"
    echo "      🔗 Link: ${LINK_SLUG:-"N/A"}"
    echo "      🏷️ Link type: ${LINK_TYPE:-"N/A"}"
    echo "      📄 Action context file: ${ACTION_CONTEXT_FILE:-"None"}"
    # Debugging: Print the notification payload
    # echo "      🔹 Notification payload: $ACTION_CONTEXT"
}

# This function updates action results based on the given JSON response
update_action_results() {
    local json_response="$1"
    local is_service="$2"

    # Debugging: Print the service attributes
    # echo "🔹 Service attributes: $json_response"

    if [[ -n "$json_response" ]]; then
        echo "🛠️ Preparing to update action results with results: $json_response"
        if [[ "$is_service" == "true" ]]; then
            echo "🔄 Updating service action results..."
            np service action update --results "$json_response"
        else
            echo "🔗 Updating link action results..."
            np link action update --results "$json_response"
        fi
    else
        echo "⚠️ No results found. Skipping update."
    fi
}