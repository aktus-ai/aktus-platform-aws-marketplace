#!/bin/bash
set -e

NS="aktus-ai-platform-dev"
CHART="aktus-platform"

get_endpoint() {
    local svc="$1"
    local ip=$(kubectl get svc "$svc" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    [[ -z "$ip" ]] && ip=$(kubectl get svc "$svc" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [[ -z "$ip" ]] && ip=$(kubectl get svc "$svc" -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    [[ -n "$ip" ]] && echo "http://$ip:8080" || echo "Service not found"
}

update_efs() {
    local efs_id="$1"
    echo "Updating EFS in chart values: $efs_id"
    for service in aktus-embedding-service aktus-inference-service aktus-multimodal-data-ingestion-service aktus-research-service; do
        # Update EFS ID in values.yaml
        sed -i.bak "s/fileSystemId: \"[^\"]*\"/fileSystemId: \"$efs_id\"/g" "$CHART/charts/$service/values.yaml" 2>/dev/null && echo "Updated $service"
    done
}

create_storage_class() {
    local efs_id="$1"
    echo "Creating/updating storage class with EFS: $efs_id"
    
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: $efs_id
  directoryPerms: "700"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
}

install() {
    local efs_id="$1"
    [[ -z "$efs_id" ]] && { echo "Usage: efs <efs-id>"; exit 1; }
    
    # Create storage class first
    create_storage_class "$efs_id"
    
    # Update chart values
    update_efs "$efs_id"
    
    echo "Installing..."
    cd aktus-platform && helm upgrade --install aktus-ai-platform . -n aktus-ai-platform-dev --create-namespace --force
    cd ..
    
    # Patch general-purpose nodepool to support GPU instances for inference service
    echo "Adding GPU support to general-purpose nodepool..."
    kubectl patch nodepool general-purpose --type='merge' -p='{"spec":{"template":{"spec":{"requirements":[{"key":"karpenter.sh/capacity-type","operator":"In","values":["on-demand"]},{"key":"eks.amazonaws.com/instance-category","operator":"In","values":["c","m","r","g","p"]},{"key":"eks.amazonaws.com/instance-generation","operator":"Gt","values":["4"]},{"key":"kubernetes.io/arch","operator":"In","values":["amd64"]},{"key":"kubernetes.io/os","operator":"In","values":["linux"]}]}}}}'
    
    echo "Deployment ready"
}

patch() {
    local endpoint="$(get_endpoint aktus-research)"
    echo "Patching KDA: $endpoint"
    kubectl set env deployment/aktus-knowledge-assistant -n "$NS" \
        VITE_SOCKET_URL="ws://${endpoint#http://}/chat" \
        VITE_API_BASE_URL="${endpoint}/db-manager" \
        VITE_LEASE_API_BASE_URL="${endpoint}" \
        VITE_API_EMBED_URL="${endpoint}/embeddings" && echo "Patched"
}

uninstall() {
    echo "Uninstalling..."
    cd aktus-platform && helm uninstall aktus-ai-platform -n aktus-ai-platform-dev
    echo "Uninstalled"
}

dashboard() {
    echo "Opening Kubernetes Dashboard..."
    ./dashboard-manager.sh open
}

gpu_setup() {
    echo "Adding GPU support to general-purpose nodepool..."
    kubectl patch nodepool general-purpose --type='merge' -p='{"spec":{"template":{"spec":{"requirements":[{"key":"karpenter.sh/capacity-type","operator":"In","values":["on-demand"]},{"key":"eks.amazonaws.com/instance-category","operator":"In","values":["c","m","r","g","p"]},{"key":"eks.amazonaws.com/instance-generation","operator":"Gt","values":["4"]},{"key":"kubernetes.io/arch","operator":"In","values":["amd64"]},{"key":"kubernetes.io/os","operator":"In","values":["linux"]}]}}}}'
    echo "GPU support added. Inference pods will now be scheduled on GPU instances automatically."
}

vpc_setup() {
    echo "Running VPC setup..."
    ./vpc-setup.sh
}

eks_setup() {
    echo "Running EKS setup..."
    ./eks-setup.sh
}

case "${1:-help}" in
    "efs") install "$2" ;;
    "install") install "$2" ;;
    "patch") patch ;;
    "endpoints") echo "Research: $(get_endpoint aktus-research)"; echo "KDA: $(get_endpoint aktus-knowledge-assistant)" ;;
    "dashboard") dashboard ;;
    "gpu-setup") gpu_setup ;;
    "vpc-setup") vpc_setup ;;
    "eks-setup") eks_setup ;;
    "uninstall") uninstall ;;
    *) cat << EOF
Aktus Manager

Commands:
  vpc-setup      Run VPC infrastructure setup
  eks-setup      Run EKS cluster setup
  efs <id>       Fresh install with new EFS
  install <id>   Same as efs command
  patch          Patch KDA endpoints
  endpoints      Show endpoints
  dashboard      Open Kubernetes Dashboard
  gpu-setup      Add GPU support to general-purpose nodepool
  uninstall      Remove deployment

Examples:
  $0 vpc-setup
  $0 eks-setup
  $0 efs fs-1234567890abcdef0
  $0 install fs-1234567890abcdef0
  $0 patch
  $0 dashboard
  $0 gpu-setup
  $0 uninstall

Dashboard Management:
  Use './dashboard-manager.sh' for full dashboard control:
  - install/uninstall dashboard
  - get authentication tokens
  - start/stop proxy
  - check status

GPU Management:
  GPU support is added by patching the general-purpose nodepool to include GPU instance categories (g, p).
  This allows inference pods with GPU requirements to be automatically scheduled on appropriate instances.
  No separate GPU nodepool is needed - Karpenter handles scheduling based on resource requirements.
EOF
        ;;
esac 