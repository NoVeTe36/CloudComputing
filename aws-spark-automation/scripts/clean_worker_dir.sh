#!/bin/bash

# Exit on any error
set -e

# Get the absolute path of the script's directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Set the project root directory (one level up from scripts)
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "--- Fetching Worker IPs from Terraform ---"
cd "$PROJECT_ROOT/terraform"

# Get worker IPs as a space-separated string
WORKER_IPS=$(terraform output -json worker_public_ips | jq -r '.[]')

if [ -z "$WORKER_IPS" ]; then
    echo "Error: Could not find any worker IPs. Is the cluster running?"
    exit 1
fi

echo "Found workers: $WORKER_IPS"
echo "----------------------------------------"

cd "$PROJECT_ROOT"

# Loop through each worker IP and clean the work directory
for IP in $WORKER_IPS; do
    echo ">>> Cleaning work directory on worker: $IP"
    ssh -i spark-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$IP "sudo rm -rf /opt/spark/work/*"
    echo ">>> Finished cleaning $IP"
    echo "----------------------------------------"
done

echo "--- Worker cleanup complete ---"