#!/bin/bash
#
# Bootstrap Flux GitOps on the K3s cluster
# Run this script on the control plane after K3s stack is installed
#
# Prerequisites:
#   - K3s running with kubectl access
#   - Flux CLI installed
#   - GITHUB_TOKEN environment variable set (PAT with repo access)
#
# Usage:
#   export GITHUB_TOKEN=ghp_xxxxx
#   ./bootstrap-flux.sh [github-owner] [github-repo]
#
set -euo pipefail

# Configuration
GITHUB_OWNER="${1:-vietcgi}"
GITHUB_REPO="${2:-gitops-metal-foundry}"
BRANCH="main"
CLUSTER_PATH="kubernetes"

echo "=== Flux GitOps Bootstrap ==="
echo "Started at: $(date)"
echo "GitHub: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "Branch: ${BRANCH}"
echo "Path: ${CLUSTER_PATH}"
echo ""

# Check prerequisites
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "ERROR: GITHUB_TOKEN environment variable is not set"
    echo ""
    echo "Create a GitHub Personal Access Token with 'repo' scope:"
    echo "  https://github.com/settings/tokens/new?scopes=repo"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN=ghp_xxxxx"
    echo "  $0"
    exit 1
fi

if ! command -v flux &> /dev/null; then
    echo "ERROR: flux CLI not found. Install with:"
    echo "  curl -s https://fluxcd.io/install.sh | bash"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found"
    exit 1
fi

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    echo "Make sure KUBECONFIG is set correctly"
    exit 1
fi

# Check if Flux is already bootstrapped
if kubectl get namespace flux-system &> /dev/null; then
    echo "Flux namespace exists. Checking installation status..."
    if kubectl get deployment -n flux-system source-controller &> /dev/null; then
        echo "Flux is already bootstrapped. Running reconciliation..."
        flux reconcile source git flux-system
        flux reconcile kustomization flux-system
        echo ""
        echo "Flux status:"
        flux get all
        exit 0
    fi
fi

# Run Flux pre-check
echo "Running Flux pre-flight checks..."
flux check --pre

# Bootstrap Flux
echo ""
echo "Bootstrapping Flux..."
flux bootstrap github \
    --owner="${GITHUB_OWNER}" \
    --repository="${GITHUB_REPO}" \
    --branch="${BRANCH}" \
    --path="${CLUSTER_PATH}" \
    --personal \
    --components-extra=image-reflector-controller,image-automation-controller

# Wait for Flux to be ready
echo ""
echo "Waiting for Flux to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/source-controller -n flux-system
kubectl wait --for=condition=available --timeout=300s deployment/kustomize-controller -n flux-system
kubectl wait --for=condition=available --timeout=300s deployment/helm-controller -n flux-system
kubectl wait --for=condition=available --timeout=300s deployment/notification-controller -n flux-system

# Show status
echo ""
echo "=== Flux Bootstrap Complete ==="
echo "Finished at: $(date)"
echo ""
echo "Flux components:"
flux get all
echo ""
echo "To check reconciliation status:"
echo "  flux get kustomizations"
echo "  flux get helmreleases -A"
echo ""
echo "To trigger reconciliation:"
echo "  flux reconcile kustomization flux-system --with-source"
