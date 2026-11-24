# docs/evidence.md — DSO202 Assignment 4

Command output for every task. Each item shows the command that was run and its
output. Screenshots are noted where the brief requires them.

> Status: skeleton. Each section below is filled from a real run.

## Task 1 — Repository, chart contract and cluster
- [ ] §3.2 tool check output
- [ ] chart contract table (in `README.md` §4) — one line per requirement
- [ ] `helm lint charts/tasktracker -f environments/dev/values.yaml`
- [ ] `helm lint charts/tasktracker -f environments/staging/values.yaml`
- [ ] `helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep '^kind:' | sort | uniq -c`
- [ ] `kind get clusters`, `kubectl get nodes`
- [ ] `docker ps --filter name=dso202-gitops --format '{{.Names}} {{.Ports}}'` showing 30080

## Task 2 — Install Argo CD declaratively
- [ ] `kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$' | sort | uniq -c`  (expect 6 Deployments, 1 StatefulSet)
- [ ] `kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u`  (dex, redis, argocd v3.5.6; none from Docker Hub)
- [ ] `kubectl get pods -n argocd`  (seven Running)
- [ ] `kubectl get crd | grep argoproj.io`  (applications, appprojects, applicationsets)
- [ ] `kubectl get configmap argocd-cm -n argocd -o yaml | grep -E 'timeout.reconciliation|accounts.reviewer'`
- [ ] `argocd version`
- [ ] **screenshot**: Argo CD UI after sign-in

## Task 3 — AppProjects and the root Application
- [ ] `kubectl get appproject,application -n argocd`
- [ ] `argocd app get root`  (Synced + Healthy)
- [ ] `argocd proj get dso202`
- [ ] final whitelist, with a comment for any addition
- [ ] **screenshot**: root Application resource tree
- [ ] Q1 answered in README

## Task 4 — Platform layer and Sealed Secrets
- [ ] `kubectl get applications -n argocd`, `kubectl get pods -n sealed-secrets`, `kubectl get crd sealedsecrets.bitnami.com`
- [ ] `ls -l ../dso202-keys/`  (existence and permissions only — never contents)
- [ ] `kubectl get namespaces | grep dso202`
- [ ] `kubectl get sealedsecret -n dso202-dev`
- [ ] `kubectl describe secret tasktracker-credentials -n dso202-dev`  (key names and sizes only)
- [ ] `kubectl get resourcequota,limitrange -n dso202-dev`
- [ ] history search per credential value: `git log -p --all -S'<value>' | head`  (must print nothing; record which KEYS were tested, never the values)
- [ ] `git status --short --ignored`
- [ ] both `platform-*` Applications Synced + Healthy
- [ ] Q2 answered in README

## Task 5 — Deliver the workloads
- [ ] `kubectl get applications -n argocd`  (all Synced + Healthy)
- [ ] Pod creation order showing waves: database → backend → frontend
- [ ] `kubectl logs job/tasktracker-smoke-test -n dso202-dev`
- [ ] `argocd app get tasktracker-dev` and `… tasktracker-staging`
- [ ] CRUD cycle in dev (see README §5 — port-forward the backend)
- [ ] **screenshot**: `tasktracker-dev` resource tree
- [ ] root Application state BEFORE and AFTER the first staging sync
- [ ] Q3 answered in README

## Task 6 — Access control for Argo CD users
- [ ] `argocd account list`  (admin, reviewer)
- [ ] `argocd --argocd-context reviewer app list`  (only the two tasktracker apps)
- [ ] three `can-i` results: `get applications` → yes, `sync applications` → no, `get logs` → no
- [ ] `argocd --argocd-context reviewer proj get platform`  (denied)
- [ ] after enabling the logs rule and re-applying bootstrap: `get logs` → yes
- [ ] **screenshot**: reviewer session showing Pod logs
- [ ] Q4 answered in README

## Task 7 — A release, a faulty release, and recovery
- [ ] pull request list (titles and numbers, or a screenshot)
- [ ] `git log --oneline --graph --decorate -n 15`
- [ ] `argocd app history tasktracker-dev` and `… tasktracker-staging`
- [ ] step 5 observations: new/old backend Pod, sync status, health, smoke test, frontend
- [ ] the exact log line from the failing backend Pod
- [ ] the refusal text from `argocd app rollback tasktracker-dev`
- [ ] dev and staging state after revert, fix-forward, and promotion to v1.2.0
- [ ] `argocd app history tasktracker-staging` contains NO revision with the faulty backend
- [ ] Q5 answered in README

## Task 8 — Drift, pruning and project guardrails
For each drill: **prediction (written first)**, commands, observed output, and one
sentence on whether the prediction held and which principle or setting explains it.
- [ ] Drill 1 — drift in dev is reverted (self-heal)
- [ ] Drill 2 — drift in staging is reported, not reverted
- [ ] Drill 3 — removing a file prunes the object (and why `Prune=false` protects the namespace)
- [ ] Drill 4 — the project rejects `ResourceQuota`; exact message; staging unaffected, and why

## Task 9 — Rebuild from Git
- [ ] `date` at start, `git rev-parse HEAD`, `kubectl get applications -n argocd` before
- [ ] fresh sealing-key backup taken
- [ ] cluster deleted and recreated
- [ ] key restored BEFORE the controller exists
- [ ] bootstrap re-applied (and nothing else by hand)
- [ ] order in which Applications became Healthy, with elapsed time
- [ ] both environments verified; one task created in each
- [ ] `date` at end; total elapsed time
- [ ] fresh backup from the rebuilt cluster
- [ ] Q6 answered in README

## Task 10 — Bonus (optional): multi-source Application
- [ ] changed Application file
- [ ] `argocd app get tasktracker-dev` showing two sources, Synced + Healthy
- [ ] one paragraph on when separating the sources is useful
