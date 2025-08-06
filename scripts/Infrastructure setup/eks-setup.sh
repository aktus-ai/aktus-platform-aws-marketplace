#!/bin/bash
set -e

# Get inputs
echo "EKS Cluster Setup"
echo "=================="

read -p "Cluster name: " CLUSTER_NAME
read -p "AWS Account ID: " ACCOUNT_ID
read -p "IAM user name [devops]: " IAM_USER
read -p "AWS region [us-east-1]: " AWS_REGION

# Set defaults
IAM_USER=${IAM_USER:-devops}
AWS_REGION=${AWS_REGION:-us-east-1}
K8S_NAMESPACE="aktus-ai-platform-dev"
SERVICE_ACCOUNT="aktus-ai-platform-sa"
PRINCIPAL_ARN="arn:aws:iam::${ACCOUNT_ID}:user/${IAM_USER}"

# Confirm
echo
echo "Configuration:"
echo "  Cluster: $CLUSTER_NAME"
echo "  Account: $ACCOUNT_ID"
echo "  User: $IAM_USER"
echo "  Region: $AWS_REGION"
echo "  Namespace: $K8S_NAMESPACE"
echo "  Service Account: $SERVICE_ACCOUNT"
echo
read -p "Continue? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

# Connect to cluster
echo "Connecting to cluster..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# Test connection
echo "Testing connection..."
kubectl config current-context

# Add user to EKS
echo "Adding user to EKS..."
aws eks create-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$PRINCIPAL_ARN" \
    --region "$AWS_REGION" 2>/dev/null || echo "Access entry might already exist"

# Grant admin permissions
echo "Granting admin permissions..."
aws eks associate-access-policy \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$PRINCIPAL_ARN" \
    --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
    --access-scope type=cluster \
    --region "$AWS_REGION"

# Create namespace and service account
echo "Creating namespace and service account..."

# Create namespace with proper error handling
if kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace '$K8S_NAMESPACE' already exists"
else
    echo "Creating namespace '$K8S_NAMESPACE'..."
    kubectl create namespace "$K8S_NAMESPACE"
    if [ $? -eq 0 ]; then
        echo "Namespace created successfully"
    else
        echo "Failed to create namespace. Exiting."
        exit 1
    fi
fi

# Create service account with proper error handling
if kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$K8S_NAMESPACE" >/dev/null 2>&1; then
    echo "Service account '$SERVICE_ACCOUNT' already exists in namespace '$K8S_NAMESPACE'"
else
    echo "Creating service account '$SERVICE_ACCOUNT' in namespace '$K8S_NAMESPACE'..."
    kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$K8S_NAMESPACE"
    if [ $? -eq 0 ]; then
        echo "Service account created successfully"
    else
        echo "Failed to create service account. Exiting."
        exit 1
    fi
fi

# Verify
echo "Verifying setup..."
kubectl get nodes
kubectl get namespace "$K8S_NAMESPACE"
kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$K8S_NAMESPACE"

echo "Setup complete!" 