# docs/screenshots

Real UI screenshots that the brief requires. One PNG per evidence item
below; referenced from `../evidence.md`.

| File | Task | Captures |
|---|---|---|
| `task2-argocd-ui-signed-in.png` | Task 2 | Argo CD web UI right after signing in as `admin` at `https://localhost:8080`. Must show the Applications list panel. |
| `task3-root-app-tree.png` | Task 3 | `root` Application's resource tree view, showing it created `dso202` AppProject and the child Applications (`sealed-secrets`, `platform-dev`, `platform-staging`, `tasktracker-dev`, `tasktracker-staging`). |
| `task5-tasktracker-dev-tree.png` | Task 5 | `tasktracker-dev` resource tree with StatefulSet, Deployments, Services, Job, ConfigMap, SealedSecret → Secret — all green (Synced + Healthy). |
| `task6-reviewer-pod-logs.png` | Task 6 | A reviewer session (not admin) viewing Pod logs in the UI, after the logs rule is enabled. The user chip top-right must show `reviewer`. |
| `task7-pr-list.png` | Task 7 | GitHub PR list for the release / failure / recovery cycle (optional per brief). |
