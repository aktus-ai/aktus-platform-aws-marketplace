#!/bin/bash
set -e

DASHBOARD_NS="kubernetes-dashboard"
DASHBOARD_SVC="kubernetes-dashboard"
DASHBOARD_PORT="8443"
LOCAL_PORT="8080"
PROXY_PID_FILE="/tmp/dashboard-proxy.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dashboard_status() {
    print_status "Checking dashboard deployment status..."
    
    # Check if dashboard namespace exists
    if ! kubectl get namespace "$DASHBOARD_NS" >/dev/null 2>&1; then
        print_error "Dashboard namespace '$DASHBOARD_NS' not found!"
        return 1
    fi
    
    # Check if dashboard deployment is ready
    local ready=$(kubectl get deployment kubernetes-dashboard -n "$DASHBOARD_NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment kubernetes-dashboard -n "$DASHBOARD_NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [[ "$ready" == "$desired" && "$ready" != "0" ]]; then
        print_status "Dashboard is ready ($ready/$desired replicas)"
        return 0
    else
        print_warning "Dashboard is not ready ($ready/$desired replicas)"
        return 1
    fi
}

get_token() {
    print_status "Retrieving authentication token..."
    
    # Get the token for the admin-user service account
    local token=$(kubectl -n "$DASHBOARD_NS" create token admin-user 2>/dev/null)
    
    if [[ -z "$token" ]]; then
        print_error "Failed to get authentication token"
        return 1
    fi
    
    echo -e "${BLUE}Dashboard Token:${NC}"
    echo "$token"
    echo
    echo -e "${BLUE}Token copied to clipboard (if pbcopy is available)${NC}"
    echo "$token" | pbcopy 2>/dev/null || true
    
    return 0
}

start_proxy() {
    print_status "Starting kubectl proxy for dashboard access..."
    
    # Check if proxy is already running
    if [[ -f "$PROXY_PID_FILE" ]]; then
        local pid=$(cat "$PROXY_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            print_warning "Proxy already running (PID: $pid)"
            return 0
        else
            rm -f "$PROXY_PID_FILE"
        fi
    fi
    
    # Start kubectl proxy in background
    kubectl proxy --port="$LOCAL_PORT" >/dev/null 2>&1 &
    local proxy_pid=$!
    echo "$proxy_pid" > "$PROXY_PID_FILE"
    
    # Wait a moment for proxy to start
    sleep 2
    
    if ps -p "$proxy_pid" >/dev/null 2>&1; then
        print_status "Proxy started successfully (PID: $proxy_pid)"
        print_status "Dashboard URL: http://localhost:$LOCAL_PORT/api/v1/namespaces/$DASHBOARD_NS/services/https:$DASHBOARD_SVC:/proxy/"
        return 0
    else
        print_error "Failed to start proxy"
        rm -f "$PROXY_PID_FILE"
        return 1
    fi
}

stop_proxy() {
    print_status "Stopping kubectl proxy..."
    
    if [[ -f "$PROXY_PID_FILE" ]]; then
        local pid=$(cat "$PROXY_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid"
            rm -f "$PROXY_PID_FILE"
            print_status "Proxy stopped (PID: $pid)"
        else
            print_warning "Proxy not running"
            rm -f "$PROXY_PID_FILE"
        fi
    else
        print_warning "No proxy PID file found"
    fi
}

open_dashboard() {
    print_status "Opening dashboard in browser..."
    
    # Start proxy if not running
    if ! start_proxy; then
        return 1
    fi
    
    # Get token
    echo
    get_token
    echo
    
    # Open browser
    local dashboard_url="http://localhost:$LOCAL_PORT/api/v1/namespaces/$DASHBOARD_NS/services/https:$DASHBOARD_SVC:/proxy/"
    
    if command -v open >/dev/null 2>&1; then
        open "$dashboard_url"
        print_status "Dashboard opened in browser"
    else
        print_status "Please open the following URL in your browser:"
        echo "$dashboard_url"
    fi
}

install_dashboard() {
    print_status "Installing Kubernetes Dashboard..."
    
    # Apply dashboard manifest
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    # Wait for deployment to be ready
    print_status "Waiting for dashboard to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n "$DASHBOARD_NS"
    
    # Create service account if it doesn't exist
    if ! kubectl get serviceaccount admin-user -n "$DASHBOARD_NS" >/dev/null 2>&1; then
        print_status "Creating admin service account..."
        kubectl apply -f dashboard-service-account.yaml
    fi
    
    print_status "Dashboard installation completed!"
}

uninstall_dashboard() {
    print_status "Uninstalling Kubernetes Dashboard..."
    
    # Stop proxy if running
    stop_proxy
    
    # Remove dashboard
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml 2>/dev/null || true
    
    # Remove service account
    kubectl delete -f dashboard-service-account.yaml 2>/dev/null || true
    
    print_status "Dashboard uninstalled!"
}

show_help() {
    cat << EOF
${BLUE}Kubernetes Dashboard Manager${NC}

${YELLOW}Commands:${NC}
  install       Install the Kubernetes dashboard
  uninstall     Remove the dashboard
  status        Check dashboard deployment status
  token         Get authentication token
  start         Start kubectl proxy for dashboard access
  stop          Stop kubectl proxy
  open          Open dashboard in browser (starts proxy if needed)
  url           Show dashboard URL

${YELLOW}Examples:${NC}
  $0 install    # Install dashboard
  $0 open       # Open dashboard in browser
  $0 token      # Get authentication token
  $0 status     # Check if dashboard is running
  $0 stop       # Stop proxy

${YELLOW}Dashboard Access:${NC}
  1. Run: $0 open
  2. Copy the displayed token
  3. Select "Token" authentication in the dashboard
  4. Paste the token and sign in

${YELLOW}Integration with aktus-platform-manager.sh:${NC}
  # After deploying your platform:
  ./aktus-platform-manager.sh efs fs-1234567890abcdef0
  ./dashboard-manager.sh open
EOF
}

# Main command handling
case "${1:-help}" in
    "install") install_dashboard ;;
    "uninstall") uninstall_dashboard ;;
    "status") check_dashboard_status ;;
    "token") get_token ;;
    "start") start_proxy ;;
    "stop") stop_proxy ;;
    "open") open_dashboard ;;
    "url") echo "http://localhost:$LOCAL_PORT/api/v1/namespaces/$DASHBOARD_NS/services/https:$DASHBOARD_SVC:/proxy/" ;;
    *) show_help ;;
esac 