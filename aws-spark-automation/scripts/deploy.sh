#!/bin/bash

# Exit on any error
set -e

# Get the absolute path of the script's directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Set the project root directory (one level up from scripts)
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "--- Provisioning Infrastructure with Terraform ---"
cd "$PROJECT_ROOT/terraform"
terraform init
terraform apply -auto-approve

echo "--- Waiting for instances to be ready for SSH ---"
sleep 60

echo "--- Configuring Cluster with Ansible ---"
cd "$PROJECT_ROOT"
ansible-playbook -i ansible/inventory.aws_ec2.yml ansible/playbook.yml

echo "--- Deployment Complete ---"
echo "You can now SSH into the master node to submit Spark jobs."