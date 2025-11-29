#!/bin/bash
#
# Metal Foundry - Complete Cluster Setup
#
# This script sets up a complete K3s cluster with:
#   - K3s (Kubernetes)
#   - Cilium (CNI + Ingress)
#   - Flux (GitOps)
#   - All infrastructure components via GitOps
#
# Usage:
#   sudo ./setup-cluster.sh [github-owner] [github-repo]
#
# The script is idempotent - safe to run multiple times.
#
set -euo pipefail

#=============================================================================
# Configuration
#=============================================================================
GITHUB_OWNER="${1:-vietcgi}"
GITHUB_REPO="${2:-gitops-metal-foundry}"
BRANCH="main"
CLUSTER_PATH="kubernetes"
REPO_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git"

LOG_FILE="/var/log/metal-foundry-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

#=============================================================================
# Helper Functions
#=============================================================================
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_section() { echo ""; log "========== $* =========="; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: Please run as root (sudo)"
        exit 1
    fi
}

wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    log "Waiting for pods with label '$label' in namespace '$namespace'..."
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
}

#=============================================================================
# Main Installation
#=============================================================================
log_section "Metal Foundry Cluster Setup"
log "GitHub: ${GITHUB_OWNER}/${GITHUB_REPO}"
log "Branch: ${BRANCH}"

check_root

#-----------------------------------------------------------------------------
# Step 1: Install K3s
#-----------------------------------------------------------------------------
log_section "Step 1: K3s Installation"

if ! command -v k3s &> /dev/null; then
    log "Installing K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable INSTALL_K3S_EXEC="server" sh -
else
    log "K3s already installed"
fi

# Wait for K3s API to be available (node won't be Ready until CNI is installed)
log "Waiting for K3s API to be available..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes &>/dev/null; do
    sleep 5
done
log "K3s API is ready (node will become Ready after CNI installation)"

#-----------------------------------------------------------------------------
# Step 2: Install Helm
#-----------------------------------------------------------------------------
log_section "Step 2: Helm Installation"

if ! command -v helm &> /dev/null; then
    log "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    log "Helm already installed: $(helm version --short)"
fi

#-----------------------------------------------------------------------------
# Step 3: Install Cilium
#-----------------------------------------------------------------------------
log_section "Step 3: Cilium CNI Installation"

# Install Cilium CLI
if ! command -v cilium &> /dev/null; then
    log "Installing Cilium CLI..."
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
    tar xzvf "cilium-linux-${CLI_ARCH}.tar.gz" -C /usr/local/bin
    rm -f "cilium-linux-${CLI_ARCH}.tar.gz"
else
    log "Cilium CLI already installed"
fi

# Install Cilium CNI
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium-agent --no-headers 2>/dev/null | grep -q Running; then
    log "Installing Cilium CNI..."
    cilium install --version stable \
        --set kubeProxyReplacement=true \
        --set ingressController.enabled=true \
        --set ingressController.default=true \
        --set ingressController.loadBalancerMode=shared \
        --set l2announcements.enabled=true \
        --set hubble.enabled=true \
        --set hubble.relay.enabled=true

    # Patch ConfigMap to ensure shared mode is set (workaround for CLI not applying it)
    log "Configuring Cilium ingress shared mode..."
    sleep 10
    kubectl patch configmap cilium-config -n kube-system --type=merge \
        -p '{"data":{"ingress-default-lb-mode":"shared","ingress-hostnetwork-enabled":"false"}}' || true
else
    log "Cilium already installed"
fi

# Wait for Cilium
log "Waiting for Cilium to be ready..."
cilium status --wait --wait-duration 5m || true
log "Cilium is ready"

# Configure Cilium for external access
# NOTE: In cloud environments with NAT (OCI, AWS, GCP), we DON'T use L2 LoadBalancer
# because the public IP is NAT'd by the cloud provider, not announced via ARP.
# Instead, we patch the cilium-ingress service to use externalIPs with the private IP.
log "Configuring Cilium for external access..."
PRIVATE_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/opc/v1/vnics/ 2>/dev/null | jq -r '.[0].privateIp // empty' || echo "")
if [ -z "$PRIVATE_IP" ]; then
    # Fallback: get the IP from the primary interface
    PRIVATE_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "")
fi

if [ -n "$PRIVATE_IP" ]; then
    log "Node private IP: $PRIVATE_IP"
    log "Patching cilium-ingress service with externalIPs..."
    # Wait for cilium-ingress service to be created
    until kubectl get svc cilium-ingress -n kube-system &>/dev/null; do
        log "Waiting for cilium-ingress service..."
        sleep 5
    done
    # Patch the service to add externalIPs - this makes Cilium route traffic
    # arriving at the private IP (after cloud NAT) to the ingress pods
    kubectl patch svc cilium-ingress -n kube-system --type=merge \
        -p "{\"spec\":{\"externalIPs\":[\"$PRIVATE_IP\"]}}" || true
    log "cilium-ingress service patched with externalIPs"
else
    log "WARNING: Could not determine private IP for external access"
fi

#-----------------------------------------------------------------------------
# Step 4: Install Flux
#-----------------------------------------------------------------------------
log_section "Step 4: Flux GitOps Installation"

# Install Flux CLI
if ! command -v flux &> /dev/null; then
    log "Installing Flux CLI..."
    curl -s https://fluxcd.io/install.sh | bash
else
    log "Flux CLI already installed: $(flux --version)"
fi

# Check if Flux is already bootstrapped
if kubectl get deployment -n flux-system source-controller &>/dev/null; then
    log "Flux already bootstrapped, triggering reconciliation..."
    flux reconcile source git flux-system || true
    flux reconcile kustomization flux-system || true
else
    log "Running Flux pre-flight checks..."
    flux check --pre

    log "Installing Flux components..."
    flux install

    log "Creating GitRepository source..."
    cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m
  url: ${REPO_URL}
  ref:
    branch: ${BRANCH}
EOF

    log "Creating root Kustomization..."
    cat <<EOF | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./${CLUSTER_PATH}
  prune: true
  wait: true
  timeout: 10m
EOF

    log "Waiting for Flux controllers..."
    kubectl wait --for=condition=available --timeout=300s deployment/source-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/kustomize-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/helm-controller -n flux-system
    kubectl wait --for=condition=available --timeout=300s deployment/notification-controller -n flux-system

    log "Triggering initial reconciliation..."
    sleep 5
    flux reconcile source git flux-system
    flux reconcile kustomization flux-system
fi

log "Flux is ready"

#-----------------------------------------------------------------------------
# Step 5: Setup User Access
#-----------------------------------------------------------------------------
log_section "Step 5: User Access Setup"

# Setup kubeconfig for ubuntu user
if id ubuntu &>/dev/null; then
    log "Setting up kubeconfig for ubuntu user..."
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    sed -i 's/127.0.0.1/localhost/g' /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube
    grep -q 'KUBECONFIG' /home/ubuntu/.bashrc || echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc
fi

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
log_section "Setup Complete!"

echo ""
echo "Versions:"
echo "  K3s:    $(k3s --version | head -1)"
echo "  Helm:   $(helm version --short 2>/dev/null || echo 'installed')"
echo "  Cilium: $(cilium version --client 2>/dev/null | head -1 || echo 'installed')"
echo "  Flux:   $(flux --version 2>/dev/null || echo 'installed')"
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
echo "Flux Status:"
flux get kustomizations
echo ""
echo "GitOps will now automatically deploy:"
echo "  - Sealed Secrets"
echo "  - Cert-Manager + Let's Encrypt issuers"
echo "  - Local-path storage provisioner"
echo "  - Prometheus + Grafana monitoring"
echo "  - Cilium ingress controller"
echo ""
echo "To monitor deployment progress:"
echo "  watch flux get kustomizations"
echo "  watch kubectl get helmreleases -A"
echo ""
echo "To access as ubuntu user, logout and login again, or run:"
echo "  export KUBECONFIG=/home/ubuntu/.kube/config"
echo ""
log "Setup completed at $(date)"
