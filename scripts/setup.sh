#!/usr/bin/env bash
# Create a local kind cluster, install Argo CD, and point it at app/
set -euo pipefail
cd "$(dirname "$0")/.."

ARGOCD_VERSION=v3.5.5
CLUSTER=k8s-demo

docker info >/dev/null 2>&1 || { echo "Docker Desktop is not running. Start it first."; exit 1; }

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi
kubectl config use-context "kind-$CLUSTER"

echo "Installing Argo CD $ARGOCD_VERSION..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

# Check Git every 30s instead of the default ~3 min, so the demo doesn't wait
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"30s"}}'
kubectl -n argocd rollout restart statefulset argocd-application-controller
kubectl -n argocd rollout restart deployment argocd-repo-server

echo "Waiting for Argo CD to be ready..."
kubectl -n argocd rollout status deployment argocd-server --timeout=300s
kubectl -n argocd rollout status deployment argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset argocd-application-controller --timeout=300s

kubectl apply -f argocd/application.yaml

echo "Waiting for the app to be deployed by Argo CD..."
until kubectl -n demo get deployment podinfo >/dev/null 2>&1; do sleep 3; done
kubectl -n demo rollout status deployment podinfo --timeout=300s
echo "Done. Run ./scripts/open-ui.sh"
