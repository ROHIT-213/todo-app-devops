#!/bin/bash

set -e

echo "Starting Terraform backend bootstrap..."

cd terraform/bootstrap

echo "Initializing bootstrap Terraform..."
terraform init

echo "Applying bootstrap resources..."
terraform apply -auto-approve

echo "Bootstrap completed successfully."