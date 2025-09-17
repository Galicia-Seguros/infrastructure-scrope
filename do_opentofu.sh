#!/bin/bash
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR
build_iac_key() {
    service_slug="$SERVICE_SLUG"
    service_id="$SERVICE_ID"
    link_slug="$LINK_SLUG"
    link_id="$LINK_ID"
    type="$ACTION_TYPE"
    specification_slug="$ACTION_SLUG"


    # Build the state string
    if [[ -n "$service_slug" && -z "$link_slug" ]]; then
        state="service-${service_slug}-${service_id}"
    fi

    if [[ -n "$service_slug" && -n "$link_slug" ]]; then
        state="service-${service_slug}-link-${link_slug}-${link_id}"
    fi

    echo "${state}.tfstate"
}

# Call the function and store the result


echo "Executing tofu service"
set -e

if [ -z "$NP_ACTION_CONTEXT" ]; then
  echo "Error: NP_ACTION_CONTEXT is not set"
  exit 1
fi

if [ -z "$BUCKET" ]; then
  echo "Error: BUCKET is not set."
  exit 1
fi

if [ -z "$DYNAMODB_TABLE" ]; then
  echo "Error: DYNAMODB_TABLE is not set."
  exit 1
fi


if [ -z "$IAC_KEY" ]; then
  export IAC_KEY=$(build_iac_key)
fi

echo "IAC_KEY: $IAC_KEY"

if [ -z "$IAC_PATH" ]; then
  export IAC_PATH=$(np service-action get-exec-path --query .path)
fi

cd $IAC_PATH
echo "Working in directory $IAC_PATH"
# Run Terraform initialization with backend configuration
tofu init -reconfigure \
  -backend-config="bucket=$BUCKET" \
  -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
  -backend-config="key=$IAC_KEY" \

ESCAPED_CONTEXT=$(echo "$NP_ACTION_CONTEXT" | sed 's/^"\(.*\)"$/\1/')

# Initialize variables to store results
IAC_OUTPUT=""
if [ -z "$IAC_ACTION" ]; then
  if [[ "$ACTION_TYPE" == "delete" ]]; then
      export IAC_ACTION="destroy"
  else
      export IAC_ACTION="apply"
  fi
fi
echo "IAC_ACTION is set to $IAC_ACTION"

# Stream Tofu output while capturing messages
tofu "$IAC_ACTION" -auto-approve -var="context=$ESCAPED_CONTEXT"
OUT_STATUS=$?

if [[ $OUT_STATUS -ne 0 ]]; then
  echo "tofu exit code $OUT_STATUS"
  exit $OUT_STATUS
fi
if [[ "$IAC_ACTION" == "apply" ]]; then
  # Capture the output of Terraform/Tofu
  IAC_OUTPUT=$(tofu output -json | jq -r -c 'with_entries(if .value | type == "object" then .value = .value.value else . end) | @json')
  echo $IAC_OUTPUT
  # Final update based on the job status
  if [[ $ACTION_LINK_ID ]]; then
    np link action update --results "$IAC_OUTPUT"
  elif [[ $ACTION_SERVICE_ID ]]; then
    np service action update --results "$IAC_OUTPUT"
  fi
fi