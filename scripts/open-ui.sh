#!/usr/bin/env bash
# Open Argo CD UI on https://localhost:8080 and the app on http://localhost:9898
set -euo pipefail

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "Argo CD:  https://localhost:8080   (user: admin  password: $PASSWORD)"
echo "App:      http://localhost:9898"
echo "Press Ctrl+C to stop."

# Re-start port-forwards if they drop (e.g. when pods are replaced)
trap 'kill 0' EXIT
(while true; do kubectl -n argocd port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 || true; sleep 1; done) &
(while true; do kubectl -n demo port-forward svc/podinfo 9898:9898 >/dev/null 2>&1 || true; sleep 1; done) &
wait
