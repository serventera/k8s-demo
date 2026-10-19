#!/usr/bin/env bash
# Start OrbStack's built-in Kubernetes, install Argo CD, and point it at app/
set -euo pipefail
cd "$(dirname "$0")/.."

ARGOCD_VERSION=v3.5.5

command -v orb >/dev/null || { echo "OrbStack is not installed: brew install --cask orbstack"; exit 1; }
orb start k8s
until kubectl config get-contexts orbstack >/dev/null 2>&1; do sleep 2; done
# Always use the local OrbStack cluster, never a real one
kubectl config use-context orbstack
until kubectl get nodes >/dev/null 2>&1; do sleep 2; done

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
