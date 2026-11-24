# dso202-gitops — DSO202 Assignment 4

GitOps delivery of the Task Tracker with Argo CD. Continuation of Assignments
1–3: the application images, API and schema are unchanged, the Helm chart is
the Assignment 3 chart adjusted to the chart contract, and the quota, limits
and RBAC are the Assignment 2 manifests.

> **Before anything else:** replace the placeholder in every file.
> ```bash
> grep -rl '<github-username>' . | xargs sed -i '' 's|<github-username>|YOUR_GH_USER|g'   # macOS
> grep -rn '<github-username>' .   # must print nothing
> ```

## 1. Pinned versions (brief §3.1 — do not change)

| Component | Version |
|---|---|
| Argo CD (and `argocd` CLI) | v3.5.6 |
| Sealed Secrets Helm chart | 2.20.0 |
| Sealed Secrets controller | 0.40.0 |
| `kubeseal` | v0.40.0 |
| Application images | `1.0` baseline, `1.1` release (Task 7) |

`latest`, `stable`, `master` and `HEAD` are not used as a version anywhere.

## 2. Build the whole environment from an empty machine

```bash
# 0. Tool check (brief §3.2)
docker version --format '{{.Server.Version}}'; kind version; kubectl version --client
helm version --short; git --version; argocd version --client; kubeseal --version

# 1. Cluster
kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml
kubectl config current-context          # kind-dso202-gitops

# 2. Restore the sealing key BEFORE the controller exists (rebuild only)
kubectl create namespace sealed-secrets
kubectl apply -f ../dso202-keys/sealing-key.backup.yaml

# 3. Argo CD — server-side apply is required (the ApplicationSet CRD exceeds
#    the 262144-byte annotation limit of client-side apply)
kubectl apply -k bootstrap/argocd --server-side --force-conflicts
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

# 4. The only Application created by hand
kubectl apply -f bootstrap/root

# 5. Watch everything else arrive in wave order
kubectl get applications -n argocd -w

# 6. Sign in and synchronise staging (manual by design)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd app sync tasktracker-staging
```

Cleanup:

```bash
kind delete cluster --name dso202-gitops
```

## 3. How credentials are handled

No credential value appears in this repository or its history, in any form.

* The plaintext input lives only in `secrets-plain/`, which `.gitignore`
  excludes and which is deleted once sealing is done.
* `kubeseal` encrypts it with the public key of this cluster's controller; the
  committed `SealedSecret` can be decrypted only by that controller.
* Scope is **strict** (the default): the name and namespace are part of what is
  encrypted, so dev and staging are sealed separately and the files are not
  interchangeable.
* The chart renders **no** `Secret` (contract C3). Pods read
  `tasktracker-credentials`, created in the namespace by the controller.
* The controller's private key is backed up outside the repository at
  `../dso202-keys/sealing-key.backup.yaml`, mode 600.

## 4. Chart contract (brief Task 1, step 4)

| # | Requirement | Satisfied in |
|---|---|---|
| C1 | Image repository and tag are values per tier | `charts/tasktracker/values.yaml` → `images.<tier>.repository` / `.tag`; no tag in any template |
| C2 | Per-tier config from values | `values.yaml` → `backend.extraEnv`, consumed by `templates/backend-deployment.yaml` |
| C3 | No `Secret` rendered; `existingSecret` used | no `secret.yaml` in `templates/`; `values.yaml` → `existingSecret`, referenced by backend + StatefulSet |
| C4 | Readiness probes on all three tiers | `statefulset.yaml` (`pg_isready`), `backend-deployment.yaml` (`GET /api/status`), `frontend-deployment.yaml` (`GET /`) |
| C5 | Sync waves db 0, backend 1, frontend 2 | `values.yaml` → `syncWaves`; annotation on each workload |
| C6 | `progressDeadlineSeconds: 120` | `values.yaml` → `progressDeadlineSeconds`; both Deployments |
| C7 | Requests and limits on every container | `values.yaml` → `<tier>.resources`; smoke-test Job declares its own |
| C8 | No Namespace/Quota/LimitRange/Role/RoleBinding | those live in `platform/<env>/`; chart renders only the six whitelisted kinds |
| C9 | Ingress disabled by default | `values.yaml` → `ingress.enabled: false`; no ingress template exists |
| C10 | Frontend Service NodePort, port a value | `services.yaml`; `environments/dev` 30080, `environments/staging` 30081 |
| C11 | `helm lint` clean, `helm template` succeeds | see `docs/evidence.md`, Task 1 |

`values.schema.json` additionally **rejects** `tag: latest`, an environment
other than `dev`/`staging`, `ingress.enabled: true`, and a NodePort backend —
so three non-negotiable constraints fail at render time rather than in review.

## 5. Browser access (read before Task 5)

The frontend's nginx does **not** proxy `/api`; `app.js` calls
`${BACKEND_URL}/api/...` **from the browser**. With no ingress controller in
this assignment (C9) and the backend on ClusterIP (never NodePort), the backend
has no browser-reachable address. The page therefore loads at
`http://localhost:30080` but its API calls fail unless a port-forward is
running on the port named in `frontend.backendUrl`:

```bash
kubectl -n dso202-dev port-forward svc/tasktracker-backend 8080:8080
```

The CRUD cycle is then performed as Assignment 1 permits — "through the
frontend **or** via curl through a port-forwarded backend". The smoke-test hook
is unaffected: it runs *inside* the cluster and reaches `…-backend:8080`
directly.

## 6. Written answers

**Q1 — Why is `platform` applied by hand while `dso202` is created by the root?**

The root Application must already have a project to belong to before it can
exist, so `platform` cannot be delivered by the thing that depends on it; this
is the bootstrap step that every GitOps installation needs. `dso202` has no
such circularity: by the time the root is running it can create the workload
project like any other file, which keeps it under version control and under
review. The risk of letting `dso202` deploy into the `argocd` namespace is
privilege escalation: anything that can write to that namespace can create
`Application` and `AppProject` objects, so a workload project could mint itself
a new project with no restrictions. That is administrator capability, which is
why only `platform` may target `argocd`.

**Q2 — What does strict scope prevent, and what is lost if the sealing key is lost?**

Strict scope (the default) encrypts the Secret's *name and namespace* along
with its values, so the ciphertext decrypts only as that name in that
namespace. It prevents a committed `SealedSecret` being copied into another
namespace — or renamed — to have the controller decrypt a credential the copier
is not entitled to. If the sealing key is lost, every `SealedSecret` sealed for
that cluster becomes permanently undecryptable: the ciphertext in Git is not
recoverable by any other means. The repository is then no longer sufficient to
rebuild the system. Recovery requires the original plaintext from a password
manager, re-sealing it against the new controller's key, and committing the new
files; the old ones are deleted. This is why the key is backed up outside Git
before anything is sealed, and re-backed-up after the controller renews it
(every 30 days) and after any rebuild.

**Q3 — `Synced` vs `Healthy`.**

`Synced` compares the *cluster* with *Git*: the objects that Git describes
exist and match. `Healthy` asks whether those objects are actually working —
Pods ready, rollouts complete. They are independent, and the gap between them
is where most incidents live. Task 7 produces the clearest example: after the
faulty backend release is merged, `tasktracker-dev` is `Synced` (the cluster
holds exactly what Git says) and `Degraded` (the new backend Pod never becomes
ready, and `progressDeadlineSeconds: 120` reports it). A second example is
`tasktracker-staging` before its first sync: Git is unchanged but nothing has
been applied, so it is `OutOfSync` and `Missing`.
*(Paste the `argocd app get` output of whichever one you observed.)*

**Q4 — Argo CD RBAC vs Kubernetes RBAC.**

Kubernetes RBAC controls what an identity may do *against the Kubernetes API* —
`Role`/`RoleBinding` objects in the cluster, configured here in
`platform/<env>/rbac.yaml`. Argo CD RBAC controls what a person may do *inside
Argo CD* — view an Application, trigger a sync, read logs through the UI — and
is configured in the `argocd-rbac-cm` ConfigMap
(`bootstrap/argocd/argocd-rbac-cm-patch.yaml`). They are enforced by different
components and neither implies the other: the `reviewer` account has no
Kubernetes credentials at all, and Argo CD itself applies manifests with its
own service account regardless of who pressed Sync.
With SSO, `policy.csv` would stop naming local accounts and would bind
**groups** asserted by the identity provider instead, e.g.
`g, <org>:dso202-reviewers, role:dso202-readonly`, with a `role:` definition
holding the permission lines. Local accounts (`accounts.reviewer`) would no
longer be needed.

**Q5 — Why is `argocd app rollback` refused, and why `git revert`?**

Rollback is refused on an Application with automated sync because the two
contradict each other: rollback would set the cluster to a previous revision,
and the controller would immediately detect the difference from Git and sync it
straight back. The documentation therefore blocks it rather than allowing a
fight. The GitOps equivalent is to change the thing the cluster follows — a
commit on `main`, which the controller then applies on its own. `git revert` is
preferred to deleting the bad commit because it *adds* a commit that undoes the
change, leaving the history complete: the faulty release, the moment it was
caught, and the recovery all remain visible and auditable. Deleting the commit
would rewrite shared history, break every clone and tag that referenced it, and
destroy the evidence that the incident happened — which is exactly what the
"versioned and immutable" principle exists to prevent.

**Q6 (a) — One repository for chart and configuration.**

*Advantages:* a single commit can change the chart and the values it needs
together, so the two can never be out of step, and one pull request shows the
whole change; and for coursework there is one clone, one history and one URL to
submit, which keeps the bootstrap honest and reviewable.
*Disadvantages:* every person who may change the application's configuration
needs write access to the chart as well, so the blast radius of a mistake or a
compromised account is larger; and the environments cannot be versioned
independently of the chart, so dev following `main` means a chart edit reaches
dev immediately, whether or not a values change was intended.

**Q6 (b) — What is not under GitOps control after the rebuild.**

| Not in GitOps | How a production team usually handles it |
|---|---|
| The bootstrap layer (`bootstrap/argocd`), applied by hand | A provisioning pipeline or cluster-creation tool (Terraform, Crossplane, a cluster API template) runs it as part of standing up the cluster. |
| The root Application, applied by hand | Created by the same provisioning step, or by an ApplicationSet owned by a management cluster that bootstraps workload clusters. |
| The sealing key | Stored in a managed secret store (KMS, Vault) with audited access and automated rotation, not in a file beside the repository. |
| The database contents | Scheduled backups to object storage with tested restores — usually by a database operator (CloudNativePG, Zalando) rather than by the delivery system. |
| Argo CD's own admin password and local accounts | Replaced by SSO against the organisation's identity provider, so no local account exists to manage. |

## 7. Repository layout

See brief §7. One concern per directory: `bootstrap/` is applied by hand once
per cluster; `argocd/` is watched by the root Application; `platform/` holds
per-environment plain manifests; `charts/` holds the application chart;
`environments/` holds only what differs between environments.
