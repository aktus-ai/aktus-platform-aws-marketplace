#!/bin/bash
set -e

echo "Setting up Aktus AI Platform..."

# Enable Helm OCI support
export HELM_EXPERIMENTAL_OCI=1

# Login to AWS ECR
echo "Logging into AWS ECR..."
aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

# Create and enter chart directory
echo "Creating awsmp-chart directory..."
mkdir awsmp-chart && cd awsmp-chart

# Pull Helm chart
echo "Pulling Helm chart..."
helm pull oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/aktus-ai/aktus-ai-platform-aws-marketplace-ecr --version 1.0.5

# Extract chart and cleanup
echo "Extracting chart..."
tar xf $(pwd)/* && find $(pwd) -maxdepth 1 -type f -delete

# Download and extract archive
echo "Downloading archive..."
curl -L "https://drive.usercontent.google.com/download?id=1GBTKm7dPMrAuZEzkMyBkHF5iNz1XV9xc&export=download&confirm=t" -o archive.zip
echo "Extracting archive..."
unzip archive.zip

# Make all shell scripts executable
echo "Making scripts executable..."
chmod +x *.sh

echo "Setup complete! You can now run ./aktus-platform-manager.sh" 