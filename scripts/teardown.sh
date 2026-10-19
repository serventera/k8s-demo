#!/usr/bin/env bash
# Delete the local OrbStack Kubernetes cluster (and everything in it)
set -euo pipefail
orb delete -f k8s
