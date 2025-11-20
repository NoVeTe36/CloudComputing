#!/bin/bash

# Terminate existing resources
echo "Terminating existing resources..."
./destroy.sh

# Deploy new resources
echo "Deploying new resources..."
./deploy.sh

echo "Restart process completed."