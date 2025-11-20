#!/bin/bash

# Exit on any error
set -e

# Get the absolute path of the script's directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Set the project root directory (one level up from scripts)
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "--- Destroying Infrastructure with Terraform ---"
cd "$PROJECT_ROOT/terraform" # This line is CRITICAL
terraform destroy -auto-approve

echo "--- Destruction Complete ---"