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

case "${1:-help}" in
    "efs") install "$2" ;;
    "install") install "$2" ;;
    "patch") patch ;;
    "endpoints") echo "Research: $(get_endpoint aktus-research)"; echo "KDA: $(get_endpoint aktus-knowledge-assistant)" ;;
    "uninstall") uninstall ;;
    *) cat << EOF
Aktus Manager

Commands:
  efs <id>       Fresh install with new EFS
  install <id>   Same as efs command
  patch          Patch KDA endpoints
  endpoints      Show endpoints
  uninstall      Remove deployment

Examples:
  $0 efs fs-1234567890abcdef0
  $0 install fs-1234567890abcdef0
  $0 patch
  $0 uninstall
EOF
        ;;
esac 