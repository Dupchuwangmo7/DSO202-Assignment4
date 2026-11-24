# docs/evidence.md — DSO202 Assignment 4

Command output for every task. Each item shows the command that was run and its
output. Screenshots are noted where the brief requires them.

> Status: skeleton. Each section below is filled from a real run.

## Task 1 — Repository, chart contract and cluster

### §3.2 tool check

```
$ docker version --format '{{.Server.Version}}'
29.4.0

$ kind version
kind v0.32.0 go1.26.3 darwin/arm64

$ kubectl version --client
Client Version: v1.36.3
Kustomize Version: v5.8.1

$ helm version --short
v4.3.0+gbec5b06

$ git --version
git version 2.54.0 (Apple Git-157)

$ argocd version --client
argocd: v3.6.2
  BuildDate: ...
  GitCommit: ...
  GitTreeState: clean
  GoVersion: ...
  Compiler: gc
  Platform: darwin/arm64

$ kubeseal --version
kubeseal version: v0.41.2
```

Drift from the brief (§3.1 pinned versions):

| Component | Pinned | Installed | Note |
|---|---|---|---|
| `argocd` CLI | v3.5.6 | v3.6.2 | Homebrew bottle; direct v3.5.6 binary download hit HTTP/2 PROTOCOL_ERROR against github.com releases. Patch-level ahead; CLI API is stable. |
| `kubeseal` | v0.40.0 | v0.41.2 | Homebrew bottle. CLI still speaks to the pinned controller v0.40.0 installed from the Helm chart. |
| Argo CD server | v3.5.6 | — | Will be installed from `bootstrap/argocd` at the pinned v3.5.6, not from brew. |
| Sealed Secrets controller | v0.40.0 | — | Will be installed from the pinned Helm chart v2.20.0, not from brew. |

- [x] §3.2 tool check output
- [x] chart contract table (in `README.md` §4) — one line per requirement

### `helm lint` — both environments clean

```
$ helm lint charts/tasktracker -f environments/dev/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm lint charts/tasktracker -f environments/staging/values.yaml
==> Linting charts/tasktracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

### Kinds rendered — only the six whitelisted (contract C8)

```
$ helm template tasktracker charts/tasktracker -f environments/dev/values.yaml \
    | grep '^kind:' | sort | uniq -c
   1 kind: ConfigMap
   2 kind: Deployment
   1 kind: Job
   3 kind: Service
   3 kind: ServiceAccount
   1 kind: StatefulSet
```

No `Secret`, `Namespace`, `ResourceQuota`, `LimitRange`, `Role` or `RoleBinding`
is emitted; those live in `platform/<env>/`.

### Cluster up, port 30080 mapped to the new cluster

```
$ kind get clusters
dso202-assignment-01
dso202-assignment-02
dso202-assignment-03
dso202-gitops
kind

$ kubectl config current-context
kind-dso202-gitops

$ kubectl get nodes
NAME                          STATUS   ROLES           AGE   VERSION
dso202-gitops-control-plane   Ready    control-plane   22s   v1.36.1

$ docker ps --filter name=dso202-gitops --format '{{.Names}} {{.Ports}}'
dso202-gitops-control-plane 0.0.0.0:30080->30080/tcp, 127.0.0.1:59372->6443/tcp
```

- [x] `helm lint charts/tasktracker -f environments/dev/values.yaml`
- [x] `helm lint charts/tasktracker -f environments/staging/values.yaml`
- [x] `helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep '^kind:' | sort | uniq -c`
- [x] `kind get clusters`, `kubectl get nodes`
- [x] `docker ps --filter name=dso202-gitops --format '{{.Names}} {{.Ports}}'` showing 30080

## Task 2 — Install Argo CD declaratively

### Rendered workload counts (6 Deployments, 1 StatefulSet)

```
$ kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$' | sort | uniq -c
   6 kind: Deployment
   1 kind: StatefulSet
```

### Images — Argo CD pinned to v3.5.6, none from Docker Hub

```
$ kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u
        image: ghcr.io/dexidp/dex:v2.45.1
        image: public.ecr.aws/docker/library/redis:8.2.3-alpine
        image: quay.io/argoproj/argocd:v3.5.6
```

### Seven Pods Running after `kubectl apply -k bootstrap/argocd --server-side --force-conflicts`

```
$ kubectl get pods -n argocd
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          4m44s
argocd-applicationset-controller-58bb5c7479-vk8b9   1/1     Running   0          4m44s
argocd-dex-server-dd6b85d9c-frtkx                   1/1     Running   0          4m44s
argocd-notifications-controller-6b85c65458-wnrv7    1/1     Running   0          4m44s
argocd-redis-869b85489d-m6k6h                       1/1     Running   0          4m44s
argocd-repo-server-5bf66565cd-ws6sw                 1/1     Running   0          4m44s
argocd-server-7474bb8f76-xxsks                      1/1     Running   0          4m44s
```

### CRDs installed

```
$ kubectl get crd | grep argoproj.io
applications.argoproj.io      2026-11-24T17:28:47Z
applicationsets.argoproj.io   2026-11-24T17:28:48Z
appprojects.argoproj.io       2026-11-24T17:28:48Z
```

### ConfigMap patches took effect

```
$ kubectl get configmap argocd-cm -n argocd -o yaml | grep -E 'timeout.reconciliation|accounts.reviewer'
  accounts.reviewer: login
  timeout.reconciliation: 60s
  timeout.reconciliation.jitter: 10s
```

### `argocd version` — CLI logged in, server at v3.5.6

```
$ argocd login localhost:8080 --username admin --insecure
'admin:login' logged in successfully

$ argocd version
argocd: v3.6.2
  …
argocd-server: v3.5.6
  BuildDate: 2026-10-20T18:33:20Z
```

The CLI is v3.6.2 (Homebrew; pinned binary download failed earlier) but
the **server itself is v3.5.6** as the brief pins.

- [x] `kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$' | sort | uniq -c`  (expect 6 Deployments, 1 StatefulSet)
- [x] `kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u`  (dex, redis, argocd v3.5.6; none from Docker Hub)
- [x] `kubectl get pods -n argocd`  (seven Running)
- [x] `kubectl get crd | grep argoproj.io`  (applications, appprojects, applicationsets)
- [x] `kubectl get configmap argocd-cm -n argocd -o yaml | grep -E 'timeout.reconciliation|accounts.reviewer'`
- [x] `argocd version`
- [ ] **screenshot**: Argo CD UI after sign-in → `screenshots/task2-argocd-ui-signed-in.png`

## Task 3 — AppProjects and the root Application
- [ ] `kubectl get appproject,application -n argocd`
- [ ] `argocd app get root`  (Synced + Healthy)
- [ ] `argocd proj get dso202`
- [ ] final whitelist, with a comment for any addition
- [ ] **screenshot**: root Application resource tree → `screenshots/task3-root-app-tree.png`
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
- [ ] **screenshot**: `tasktracker-dev` resource tree → `screenshots/task5-tasktracker-dev-tree.png`
- [ ] root Application state BEFORE and AFTER the first staging sync
- [ ] Q3 answered in README

## Task 6 — Access control for Argo CD users
- [ ] `argocd account list`  (admin, reviewer)
- [ ] `argocd --argocd-context reviewer app list`  (only the two tasktracker apps)
- [ ] three `can-i` results: `get applications` → yes, `sync applications` → no, `get logs` → no
- [ ] `argocd --argocd-context reviewer proj get platform`  (denied)
- [ ] after enabling the logs rule and re-applying bootstrap: `get logs` → yes
- [ ] **screenshot**: reviewer session showing Pod logs → `screenshots/task6-reviewer-pod-logs.png`
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
