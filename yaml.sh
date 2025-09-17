#!/bin/bash

generate_values_yaml() {
    local values_template="$1"
    local context_file="$2"  # Optional JSON context file

    if [[ -z "$values_template" ]]; then
        echo "Error: Missing values template file parameter."
        return 1
    fi

    if [[ ! -f "$values_template" ]]; then
        echo "Error: Values template '$values_template' not found!"
        return 1
    fi

    # Create a temporary file for processing
    local temp_file=$(mktemp)
    cp "$values_template" "$temp_file"

    # First pass: Process environment variables with envsubst
    envsubst < "$temp_file" > "$temp_file.env"
    mv "$temp_file.env" "$temp_file"

    # Second pass: Process jq expressions if context file is provided
    if [[ -n "$context_file" && -f "$context_file" ]]; then
        # Find all jq expressions in the template with pipe-based format: {{ jq | expression }}
        grep -o '{{ jq |[^}]*}}' "$temp_file" | while read -r match; do
            # Extract the jq expression (everything between '{{ jq |' and '}}')
            jq_expr=$(echo "$match" | sed 's/{{ jq |\(.*\)}}/\1/')
            
            # Execute the jq expression against the context file
            result=$(jq -r "$jq_expr" "$context_file")
            
            # Use Python to safely replace text in the file
            python3 -c "
import re
with open('$temp_file', 'r') as f:
    content = f.read()
content = content.replace('$match', '$result')
with open('$temp_file', 'w') as f:
    f.write(content)
"
        done
    fi

    # Output the final processed template
    cat "$temp_file"
    rm $temp_file
}

generate_values_yaml_file() {
    local FILE=$(mktemp)
    generate_values_yaml "$1" "$2" > "$FILE"
    echo "$FILE"
}