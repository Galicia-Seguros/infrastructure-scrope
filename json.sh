#!/bin/bash

# Function to extract a specific field from JSON using jq
extract_json_field() {
  local json_payload="$1"
  local jq_expression="$2"
  echo "$json_payload" | jq -r "$jq_expression"
}

# Runs each JSON-producing command, optionally filters with jq.
build_json_object() {
  local cmd="$1"
  local jq_expr="$2"

  # Ensure jq expression defaults to '.'
  [[ -z "$jq_expr" ]] && jq_expr="."

  # Run command and capture stdout
  local output
  if ! output=$(bash -c "$cmd" 2>&1); then
      echo "❌ Error: Command failed: $cmd" >&2
      echo "{}"
      return 0
  fi

  # Debugging: Print the raw output
  # echo "🔹 Raw output: $output" >&2

  # Ensure output is not empty
  if [[ -z "$output" ]]; then
      echo "⚠️ Warning: Command output is empty: $cmd" >&2
      echo "{}"
      return 0
  fi

  # Check if the output is already valid JSON
  if ! echo "$output" | jq -e . &>/dev/null; then
      # Convert raw text into a JSON-safe string
      output=$(echo "$output" | jq -R -c .)
  fi

  # Apply jq expression safely
  local transformed
  if ! transformed=$(echo "$output" | jq -cer "$jq_expr" 2>/dev/null); then
      echo "⚠️ Warning: jq filter '$jq_expr' failed or returned invalid JSON." >&2
      echo "{}"
      return 0
  fi

  echo "$transformed"
}

merge_json() {
  # Usage: merge_json "$JSON1" "$JSON2" ...
  jq -s 'reduce .[] as $item ({}; . * $item)' < <(printf "%s\n" "$@")
}