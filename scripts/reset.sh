#!/usr/bin/env bash
# Put app/ back to the starting state (git tag "demo-start") and push to main
set -euo pipefail
cd "$(dirname "$0")/.."

git checkout main
git pull --ff-only
git checkout demo-start -- app/
if git diff --cached --quiet; then
  echo "app/ is already at the starting state."
else
  git commit -m "Reset demo to starting state"
  git push origin main
fi
# Remove leftover local demo branches
git branch --format='%(refname:short)' | grep -v '^main$' | xargs -r git branch -D || true
echo "Reset done. Argo CD will sync within ~30s."
