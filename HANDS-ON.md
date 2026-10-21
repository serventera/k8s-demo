# Hands-on: your first Kubernetes deployment

You'll run Kubernetes on your own Mac and deploy a small web app ([podinfo](https://github.com/stefanprodan/podinfo)).

- **Part A (everyone):** deploy and change the app yourself with `kubectl`.
- **Part B (optional):** let **Argo CD** deploy it from Git, like in the demo.

---

## Part A: Deploy with kubectl

### 1. Turn on Kubernetes in OrbStack

If you don't have OrbStack yet: `brew install --cask orbstack`, then open it from Applications.

In OrbStack: **Settings → Kubernetes → Enable Kubernetes**, then wait about a minute.
(Or in a terminal: `orb start k8s`)

### 2. Connect kubectl to your local cluster

OrbStack already added a connection called `orbstack` to your kubectl config. Select it:

```bash
kubectl config use-context orbstack
kubectl get nodes
```
✅ You should see one node named `orbstack` with status `Ready`.

<details>
<summary>❌ <code>kubectl: command not found</code>, or <code>kubectl version --client</code> shows something older than v1.30?</summary>

```bash
brew install kubectl      # or: brew upgrade kubectl
which -a kubectl          # the first line should be /opt/homebrew/bin/kubectl
```
If an old one in `/usr/local/bin` comes first, open a new terminal or run `/opt/homebrew/bin/kubectl` directly.
</details>

> 💡 `kubectl config get-contexts` lists every cluster you can talk to. The one with `*` is the one your commands go to. **Always check it says `orbstack`** before changing anything.

### 3. Get the files

```bash
cd ~
git clone https://github.com/serventera/k8s-demo.git
cd k8s-demo
```
Open the folder in your editor and have a look at `app/deployment.yaml` and `app/service.yaml`.

### 4. Deploy

```bash
kubectl create namespace demo     # a namespace is like a folder for your app
kubectl apply -f app/             # send both files to Kubernetes
kubectl get pods -n demo          # repeat until both pods show Running
```

### 5. Open the app

In a **second terminal**, run this and leave it open:

```bash
kubectl port-forward -n demo svc/podinfo 9898:9898
```
Open http://localhost:9898 🎉

> If the page stops loading after a change, the old pods it was connected to are gone. Press Ctrl+C and run the port-forward again.

### 6. Exercises

For each one: **edit `app/deployment.yaml` → save → `kubectl apply -f app/` → watch.**
Watch with: `kubectl get pods -n demo -w` (Ctrl+C to stop).

1. **Desired state:** delete a pod and watch Kubernetes replace it.
   ```bash
   kubectl get pods -n demo
   kubectl delete pod -n demo <one-pod-name>
   kubectl get pods -n demo
   ```
2. **New version:** change the image tag `6.14.1` → `6.15.0`, then apply.
   Old pods are replaced one by one. Restart the port-forward and reload: the version number changes.
3. **Scale:** `replicas: 2` → `replicas: 3`, then apply. A third pod starts.
4. **Your message:** change `PODINFO_UI_MESSAGE` to anything, and `PODINFO_UI_COLOR` to any color (e.g. `"#e91e63"`), then apply. Reload the app.
5. **Break it:** change the tag to `9.9.9` (doesn't exist), then apply.
   ```bash
   kubectl get pods -n demo                    # new pod: ImagePullBackOff, old pods still Running
   kubectl describe pod -n demo <bad-pod-name> # read the Events at the bottom
   kubectl rollout undo -n demo deployment/podinfo   # roll back
   ```
   Then set the tag back in the file too, so the file and the cluster match again.

### Handy commands

| Command | What it does |
|---|---|
| `kubectl get pods -n demo` | list pods |
| `kubectl describe pod -n demo <name>` | details + events (why is it failing?) |
| `kubectl logs -n demo <name>` | app logs |
| `kubectl rollout status -n demo deployment/podinfo` | wait for a rollout to finish |
| `kubectl rollout undo -n demo deployment/podinfo` | go back to the previous version |

---

## Part B (optional): Let Argo CD deploy from Git

So far **you** ran `kubectl apply`. With Argo CD, you only change Git, and Argo CD applies it for you.
You need a GitHub account, and Argo CD downloads ~500 MB.

### 1. Your own copy of the repo
```bash
brew install gh          # if you don't have it
gh auth login            # GitHub.com → HTTPS → Login with a web browser
cd ~
rm -rf k8s-demo          # remove the clone from Part A
gh repo create k8s-demo --public --template serventera/k8s-demo --clone
cd k8s-demo
```
This creates the public repo `github.com/<your-username>/k8s-demo`.

### 2. Install Argo CD and hand it the app
```bash
./scripts/setup.sh       # installs Argo CD and tells it to watch YOUR repo (~3-5 min)
./scripts/open-ui.sh     # leave this terminal open
```
Stop the port-forward from Part A first (Ctrl+C); `open-ui.sh` uses the same port.

| What | URL | Login |
|---|---|---|
| Argo CD | https://localhost:8080 | `admin`, password printed by the script |
| App | http://localhost:9898 | none |

Click through the certificate warning, then click the **podinfo** tile.
Argo CD takes over the app you deployed in Part A, so from now on Git is in charge.

### 3. Change the app the GitOps way
```bash
git checkout main && git pull
git checkout -b my-change              # new name each time
# edit app/deployment.yaml and save
git commit -am "My change"
git push -u origin my-change
gh pr create --fill
gh pr merge --squash --delete-branch
```
In Argo CD click **Refresh** (or wait ~30 s): **OutOfSync → Synced → Healthy**.

Try: a new version, replicas, your message. Then try to cheat:
```bash
kubectl -n demo scale deployment podinfo --replicas=5
```
Argo CD puts it back to what Git says. **Git wins.**

---

## Clean up

```bash
kubectl delete namespace demo          # remove the app
kubectl delete namespace argocd        # remove Argo CD (if you did Part B)
```
Or delete the whole local cluster: `orb delete -f k8s` (turn Kubernetes on again later with `orb start k8s`). If you did Part B, you can also delete your GitHub repo.
