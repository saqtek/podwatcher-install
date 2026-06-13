# PodWatcher — Security Reference

For general security posture and data isolation overview see FEATURES.md.
For RBAC summary and container controls see USAGE.txt.
This document covers detail required for enterprise security questionnaires and procurement reviews.

---

## RBAC — Full Permission Table with Justification

Every permission is traced to a live code path. No permission exists without one.

| API Group | Resource | Verbs | Justification |
|---|---|---|---|
| core | pods, pods/log | get, list, watch | Primary watch stream and log enrichment |
| core | pods/exec | get, **create** | Log path resolution during alert enrichment. `create` is required by the Kubernetes exec WebSocket handshake protocol — it is not used to run commands inside containers |
| core | events, namespaces, nodes, services, endpoints, persistentvolumes, persistentvolumeclaims, resourcequotas | get, list, watch | Infrastructure signal collection |
| apps | replicasets, deployments, statefulsets, daemonsets | get, list, watch | Workload owner resolution and health monitoring |
| batch | jobs, cronjobs | get, list, watch | Job failure detection |
| autoscaling | horizontalpodautoscalers | get, list, watch | HPA ceiling monitor |
| discovery.k8s.io | endpointslices | get, list, watch | Service SLI readiness ratio |
| metrics.k8s.io | pods, nodes | get, list | Resource saturation signals — gracefully skipped if metrics-server absent |
| coordination.k8s.io | leases | get, list, watch, create, update, patch | Leader election when `replicaCount > 1`. Scoped to release namespace only. The only non-read permission in the entire role |

**`pods/exec` note for security reviewers:** The exec verb is invoked exclusively to resolve log file paths during alert enrichment. It is never used to execute commands inside production containers. The operation is read-only at the application layer. The `create` verb is a Kubernetes API protocol requirement for the WebSocket upgrade handshake, not a write operation on the workload.

---

## CIS Benchmark Controls

| Control | Setting | Benchmark |
|---|---|---|
| Run as non-root | `runAsNonRoot: true`, `runAsUser: 10001` | CIS 5.2.6 |
| No privilege escalation | `allowPrivilegeEscalation: false` | CIS 5.2.5 |
| Read-only root filesystem | `readOnlyRootFilesystem: true` | CIS 5.2.4 |
| Drop all capabilities | `capabilities.drop: ["ALL"]` | CIS 5.2.7 |
| Seccomp profile | `seccompProfile.type: RuntimeDefault` | CIS 5.7.2 |

PodWatcher requires zero Linux capabilities. Standard userspace syscalls only: HTTPS (socket/connect), port 8080 (bind/listen/accept), threading (clone/futex), signal handling (sigaction).

---

## Vulnerability Scan Results

| Scanner | Result | Notes |
|---|---|---|
| Trivy | **ZERO vulnerabilities** | High, Critical, and Medium — all clean |
| Prisma Cloud | PASS | |
| Snyk | PASS | |

AWS Marketplace independently scans all container images before listing approval. Python 3.13 Alpine base with full `apk upgrade` at build time — OS-level patches applied at every release.

---

## Cross-Cloud Security Notes

| Platform | Note |
|---|---|
| EKS | IRSA injects AWS credentials via ServiceAccount token — no stored credentials |
| AKS / GKE / on-prem | No AWS IAM required — RegisterUsage is safely skipped |
| GKE Autopilot | `namespace` field on ClusterRoleBinding subject required — included in chart |
| OpenShift | `pods/exec` requires SecurityContextConstraint grant by cluster admin |
| Rancher / RKE2 | No platform-specific configuration required |

---

## Reporting a Security Issue

Contact: **support@saqtek.com**

Do not open a public GitHub issue for security vulnerabilities.
