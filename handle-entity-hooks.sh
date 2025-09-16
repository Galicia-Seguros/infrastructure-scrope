#!/bin/bash -x

WORKING_DIRECTORY="$(dirname "$(realpath "$0")")"
cd "$WORKING_DIRECTORY" || exit 1
echo "Received $NP_ACTION_CONTEXT"
export NP_TOKEN=$(curl -s --request POST \
  --url https://api.nullplatform.com/token \
  --header 'content-type: application/json' \
  --data "{
    \"api_key\": \"$NP_API_KEY\"
}" | jq -r '.access_token')
eval "$(np service-action export-action-data --format bash  --bash-prefix HOOK)"

if [[ $HOOK_ENTITY == "application" ]]; then
    export APPLICATION_ID=$(echo "$HOOK_NRN" | sed 's/.*application=\([0-9]*\).*/\1/')
    ./entity_hooks/application.sh
fi

