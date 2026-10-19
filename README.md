# Kubernetes for Developers – Live Demo

A tiny app ([podinfo](https://github.com/stefanprodan/podinfo)) deployed to a local Kubernetes cluster by **Argo CD**, straight from this Git repo.

```
app/deployment.yaml   # what to run (image, replicas, env)  ~ ECS service + task definition
app/service.yaml      # how to reach it                      ~ ECS service discovery
argocd/application.yaml  # "Argo CD, keep the cluster in sync with app/ on main"
scripts/              # setup, open UIs, reset, teardown
```

**The one idea:** you never deploy by hand. You change Git → Argo CD makes the cluster match.

## Prerequisites (macOS)

```bash
brew install --cask orbstack
brew install kubectl gh git
gh auth login
```
OrbStack must be running (it provides the local Kubernetes cluster).

## Before the demo

```bash
./scripts/setup.sh     # OrbStack Kubernetes + Argo CD v3.5.5 + the app (~3-5 min)
./scripts/open-ui.sh   # keep this terminal open
```
- Argo CD: https://localhost:8080 (accept the self-signed cert; user `admin`, password printed by the script)
- App: http://localhost:9898

Argo CD checks Git every **~30s**. Too slow on stage? Open the `podinfo` app in Argo CD and click **Refresh** at the top. It re-reads Git right away.

---

## Demo script

### 0. Warm-up (optional): desired state

```bash
kubectl create namespace warmup
# same file; we only swap the namespace so Argo CD's copy isn't touched
sed 's/namespace: demo/namespace: warmup/' app/deployment.yaml | kubectl apply -f -
kubectl get pods -n warmup
```
> 💬 "I told Kubernetes *I want 2 copies*. Here they are."

```bash
kubectl delete pod -n warmup $(kubectl get pods -n warmup -o name | head -1 | cut -d/ -f2)
kubectl get pods -n warmup -w        # Ctrl+C after the new pod is Running
```
> 💬 "I killed one. Kubernetes noticed 1 ≠ 2 and started a new one. That's *desired state*."

```bash
kubectl delete namespace warmup
```
> 💬 "That was me with kubectl. From now on, nobody runs kubectl: Git is the only way in."

### 1. Deploy a new version

```bash
git checkout -b upgrade
sed -i '' 's/podinfo:6.14.1/podinfo:6.15.0/' app/deployment.yaml
git commit -am "Upgrade podinfo to 6.15.0"
git push -u origin upgrade
gh pr create --fill
gh pr merge --squash --delete-branch
```
> 💬 "A deploy is just a pull request. Merge it, and Argo CD sees Git changed: OutOfSync → Synced → Healthy."

Watch Argo CD (click **Refresh**), then reload http://localhost:9898. The version changes to 6.15.0.
(If the app page is blank right after a rollout, wait ~5s and reload. The port-forward reconnects to the new pods.)

### 2. Scale up

```bash
git checkout main && git pull
git checkout -b scale
sed -i '' 's/replicas: 2/replicas: 3/' app/deployment.yaml
git commit -am "Scale to 3 replicas"
git push -u origin scale
gh pr create --fill
gh pr merge --squash --delete-branch
```
> 💬 "Same as changing the ECS desired count, but reviewed in a PR. Look: a third pod in the tree."

### 3. Change an environment variable

```bash
git checkout main && git pull
git checkout -b new-message
sed -i '' -e 's/Hello from Kubernetes/Hello from Git!/' -e 's/#34577c/#2e7d32/' app/deployment.yaml
git commit -am "Change message and color"
git push -u origin new-message
gh pr create --fill
gh pr merge --squash --delete-branch
```
> 💬 "Config is code too. New env vars mean new pods, rolled out one by one with no downtime."

Reload http://localhost:9898. The page is green with the new message.

### 4. (Optional) Break it, then fix it

```bash
git checkout main && git pull
git checkout -b broken
sed -i '' 's/podinfo:6.15.0/podinfo:9.9.9/' app/deployment.yaml
git commit -am "Deploy version 9.9.9"
git push -u origin broken
gh pr create --fill
gh pr merge --squash --delete-branch
```
> 💬 "Typo in the tag. The new pod shows ImagePullBackOff and the app goes Degraded, but the old pods keep serving. The site is still up."

Click the red pod in Argo CD → **Events** to show the error. Then fix it:

```bash
gh pr revert broken                               # opens a PR that undoes "broken"; prints its URL/number
gh pr merge <new PR number> --squash --delete-branch
git checkout main && git pull
```
> 💬 "Rollback = revert the PR. Git history is our deploy history."

---

## After the demo

```bash
./scripts/reset.sh      # put app/ back to the start (image 6.14.1, 2 replicas, original message)
./scripts/teardown.sh   # delete the OrbStack Kubernetes cluster
```
