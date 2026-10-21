# Hands-on: deploy with Git + Argo CD

You'll run your own Kubernetes cluster on your Mac, with Argo CD deploying a small app from **your own GitHub repo**. Then you'll change the app the GitOps way: edit → pull request → merge → Argo CD deploys it.

---

## Part 1: Before the session (at home, ~15 min)

Please do this **before** the session. It downloads about 1 GB, and conference Wi-Fi is slow.

### 1. Install the tools

You need [Homebrew](https://brew.sh). Then:

```bash
brew install --cask orbstack
brew install kubectl git gh
```

Open **OrbStack** once from Applications and finish its setup.

> Using Docker Desktop? Quit it while you use OrbStack, so they don't compete for memory.

### 2. Log in to GitHub

```bash
gh auth login        # choose: GitHub.com → HTTPS → Login with a web browser
```

### 3. Create your own copy of the demo repo

```bash
cd ~
gh repo create k8s-demo --public --template serventera/k8s-demo --clone
cd k8s-demo
```

This creates `github.com/<your-username>/k8s-demo`. It must be **public**, so Argo CD can read it without a password.

### 4. Connect kubectl to your local cluster

Turn on Kubernetes in OrbStack: **Settings → Kubernetes → Enable Kubernetes** (or run `orb start k8s`), then wait about a minute.

OrbStack adds a connection called `orbstack` to your kubectl config by itself. Select it and check:

```bash
kubectl config use-context orbstack
kubectl get nodes
```
✅ You should see one node named `orbstack` with status `Ready`.

> 💡 `kubectl config get-contexts` lists every cluster kubectl can talk to; the one marked `*` is where your commands go. Make sure it's `orbstack` before you apply anything.

<details>
<summary>❌ <code>kubectl: command not found</code>, or an old version?</summary>

```bash
brew install kubectl      # or: brew upgrade kubectl
which -a kubectl          # the first line should be /opt/homebrew/bin/kubectl
```
</details>

### 5. Deploy the app with kubectl

```bash
cd ~/k8s-demo
kubectl create namespace demo     # a namespace is like a folder for your app
kubectl apply -f app/             # sends deployment.yaml + service.yaml to Kubernetes
kubectl get pods -n demo          # repeat until both pods show Running
```

Open the app. Run this in a second terminal and leave it open:

```bash
kubectl port-forward -n demo svc/podinfo 9898:9898
```
Then go to http://localhost:9898 🎉

To change the app: edit `app/deployment.yaml`, save, and run `kubectl apply -f app/` again. Try changing the image tag to `6.15.0`, `replicas` to `3`, or the message. If the page stops loading after a change, press Ctrl+C and start the port-forward again.

### 6. Start Kubernetes + Argo CD + the app (optional)

Stop the port-forward from step 5 first (Ctrl+C). Argo CD will take over the app you deployed with kubectl.

**Tip: download the images first** (~1.3 GB unpacked). OrbStack's Kubernetes uses the same images as its Docker, so `setup.sh` will then start much faster. You can run this early, e.g. while doing steps 4–5:

```bash
docker context use orbstack
docker pull quay.io/argoproj/argocd:v3.5.5
docker pull ghcr.io/dexidp/dex:v2.45.1
docker pull public.ecr.aws/docker/library/redis:8.2.3-alpine
docker pull ghcr.io/stefanprodan/podinfo:6.14.1
docker pull ghcr.io/stefanprodan/podinfo:6.15.0
```

```bash
./scripts/setup.sh
```

This takes a few minutes. It should end with `Done. Run ./scripts/open-ui.sh`.

✅ **You're ready.** You can close everything; it'll still be there at the session.
(If you restarted your Mac, just open OrbStack again.)

---

## Part 2: During the session

### Open the UIs

In a terminal, run this and **leave it open**:

```bash
cd ~/k8s-demo
./scripts/open-ui.sh
```

| What | URL | Login |
|---|---|---|
| Argo CD | https://localhost:8080 | user `admin`, password printed by the script |
| Your app | http://localhost:9898 | none |

Your browser will warn about the certificate on 8080. That's expected, so click through ("Advanced" → "Proceed").
In Argo CD, click the **podinfo** tile to see your app.

### How every change works

Open a **second** terminal, then for each exercise:

```bash
cd ~/k8s-demo
git checkout main && git pull           # 1. start from the latest main
git checkout -b my-change               # 2. new branch (use a new name each time)
# 3. edit app/deployment.yaml in your editor and save
git commit -am "Describe your change"   # 4. commit
git push -u origin my-change            # 5. push
gh pr create --fill                     # 6. open a pull request
gh pr merge --squash --delete-branch    # 7. merge it
```

Then go to Argo CD and click **Refresh** at the top (or wait ~30 s). Watch it go **OutOfSync → Synced → Healthy**.

### Exercises (all in `app/deployment.yaml`)

1. **New version:** change the image tag `6.14.1` → `6.15.0`.
   Reload http://localhost:9898. The version number changes.
2. **Scale:** change `replicas: 2` → `replicas: 3`.
   A third pod appears in the Argo CD tree.
3. **Your message:** change `PODINFO_UI_MESSAGE` to anything you like, and `PODINFO_UI_COLOR` to any color (e.g. `"#e91e63"`).
   Reload the app. It shows your message and color.
4. **Bonus: break it.** Change the tag to `9.9.9` (doesn't exist).
   Click the red pod → **Events** to see `ImagePullBackOff`. Your old pods keep running, so the app stays up.
   Fix it with `gh pr revert <PR number>`, then `gh pr merge <new PR number> --squash --delete-branch`.
5. **Bonus: self-heal.** Try to cheat with kubectl:
   ```bash
   kubectl -n demo scale deployment podinfo --replicas=5
   ```
   Watch Argo CD put it back to what Git says. **Git wins.**

### Troubleshooting

| Problem | Fix |
|---|---|
| App page blank right after a change | Wait ~5 s and reload; the connection moves to the new pods |
| `ERR_CONNECTION_REFUSED` on 8080 / 9898 | `open-ui.sh` isn't running; start it again |
| Argo CD doesn't change | Click **Refresh**; check your PR was actually merged on GitHub |
| `git pull` conflict / messy branch | `git checkout main && git reset --hard origin/main` |
| Anything else | Run `./scripts/setup.sh` again (it's safe to re-run) |

---

## Part 3: Clean up (after the session)

```bash
./scripts/teardown.sh      # deletes the local Kubernetes cluster
```

You can also delete your GitHub repo `k8s-demo` if you don't want to keep it.
