# PodWatcher — Feature Reference

PodWatcher is a Kubernetes incident intelligence agent. It runs entirely inside
your cluster, monitors every workload continuously, and delivers actionable
alert cards — with diagnosis already written — to Microsoft Teams, Slack, or
PagerDuty the moment something breaks.

This document covers every capability included in the current release.

---

## Notification Channels

| Channel | Type | Notes |
|---|---|---|
| Microsoft Teams | Adaptive Card (rich UI) | Colour-coded P1/P2, fact tables, triage commands |
| Slack | Block Kit message | Mirrors Teams card content and structure |
| PagerDuty | Events API v2 | Triggers incidents with full context payload |

All three channels can run simultaneously. Each is independently optional —
PodWatcher starts cleanly with zero webhooks configured.

---

## Alert Priority Model

Every alert is classified at dispatch time:

| Priority | Meaning | Example triggers |
|---|---|---|
| P1 — Critical | Service is down or data is at risk | CrashLoopBackOff, OOMKilled, NodeNotReady, SLO zero-success, error-budget burn |
| P2 — Warning | Degradation detected, action required | CPU throttle, memory pressure near limit, endpoint ratio drop, GenAI SLI breach |

P1 alerts bypass all suppression gates. P2 alerts are subject to cooldown and
deduplication (see Noise Suppression below).

---

## Pod & Container Monitoring

**Crash detection**
- CrashLoopBackOff with restart count and back-off state
- OOMKilled — kernel OOM kill confirmed via exit code 137
- Container exit code triage — every exit code decoded into a human-readable
  reason (SIGKILL, SIGSEGV, SIGTERM, application error, and more)
- ImagePullBackOff and ErrImagePull — image registry failures with pull advice

**Log enrichment**
- Signal-bearing log lines extracted automatically at alert time — stack traces,
  crash tokens, and error patterns surfaced without the engineer opening a terminal
- Log snippet capped at 1,500 characters and sanitised before dispatch
- Falls back gracefully when container logs are unavailable

**Triage commands**
- Pre-populated `kubectl describe`, `kubectl logs`, and diagnostic commands
  embedded in every alert card — ready to copy and run

**RESOLVED cards**
- Automatic RESOLVED notification when a previously alerting workload returns
  to healthy state
- Time-to-Resolve (TTR) included in every RESOLVED card to support MTTR and
  MTTD reporting

---

## Workload Health Monitoring

PodWatcher monitors all standard Kubernetes workload types continuously:

| Workload type | What is checked |
|---|---|
| Deployments | Available replica ratio vs desired — alerts when availability drops below threshold |
| ReplicaSets | Replica health and readiness ratio |
| StatefulSets | Per-pod readiness, ordered rollout stalls |
| DaemonSets | Node coverage — alerts when pods are missing on schedulable nodes |
| Jobs | Failed job detection with exit reason |

All workload checks run on a fast-poll cycle (60 seconds) — not waiting for the
default Kubernetes reconciliation interval.

---

## Infrastructure Monitoring

**Node conditions**
- NodeNotReady, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
- Polled every 60 seconds for sub-minute detection on P1 node failures

**CoreDNS health**
- DNS pod availability monitored independently on a 30-second cycle
- Critical for detecting cluster-wide connectivity failures early

**Persistent Volume health**
- PV phase monitoring — Released, Failed, and orphaned volumes surfaced
- Volume attachment event detection — stale attachments after OOMKill or
  force-delete flagged before the next pod bind attempt

**Ingress errors**
- 5xx error event accumulation across ingress controllers — fires when sustained
  error rate crosses threshold

**Endpoint readiness**
- Service endpoint ratio monitoring — distinguishes between pods-are-down and
  load-balancer-is-misconfigured failure modes

**Resource Quotas**
- Namespace quota utilisation monitoring — alerts before hard limits are hit and
  new pods are rejected

---

## Service SLI / SLO Monitoring

PodWatcher tracks service-level indicators in real time:

- **Availability SLI** — endpoint ready ratio monitored continuously
- **Saturation SLI** — CPU and memory utilisation vs requests/limits with
  sustained-breach windows before alerting (configurable)
- **HPA ceiling monitor** — alerts when the autoscaler is pegged at max replicas
  and cannot scale further
- **Deployment ratio SLO** — fires when available replicas drop below the
  configured fraction of desired replicas

Sustained-breach windows prevent transient spikes from generating noise.

---

## Error Budget Burn Detection

PodWatcher tracks P1 alert frequency in a rolling window and fires a
**BudgetBurnAlert** when the rate of critical failures signals that the monthly
error budget will be exhausted before the period ends.

This gives SRE and platform teams a leading indicator — not just a record of
what already burned.

---

## GenAI / Inference Workload Monitoring

**Zero-config auto-discovery**

PodWatcher automatically identifies inference workloads by scanning container
image names and pod labels. Supported runtimes include:

vLLM · Triton Inference Server · TGI (Text Generation Inference) · TRT-LLM ·
Ray Serve · Ollama · LLaMA · Mistral · DeepSpeed · Hugging Face Transformers ·
KServe · TorchServe · ONNX Runtime · TensorRT · BentoML · SGLang · LMDeploy

No labels, no annotations, no configuration changes required.

**SLI metrics monitored per inference workload**

| Metric | Default SLO threshold | Alert type |
|---|---|---|
| Token throughput (tokens/sec) | 10 tok/s minimum | P2 — low throughput |
| Time to First Token (TTFT ms) | 2,000 ms maximum | P2 — high latency |
| Inference success rate (%) | 95% minimum | P1 — success rate breach |

All thresholds are configurable via Helm values or environment variables.

**Sustained-breach window**

GenAI alerts fire only after a breach is sustained for a configurable window
(default 5 minutes) — GPU warm-up spikes and transient load do not generate
alerts.

**Prometheus metrics**

Per-workload GenAI SLI metrics are exposed at `/metrics` on port 8080 with full
labels: workload, namespace, pod, node, and cluster.

---

## FinOps — Cost Optimisation

Every 7 days PodWatcher sends a **FinOps Efficiency Report** to your configured
channels. No additional configuration required.

**What the report surfaces:**

| Finding | How it helps |
|---|---|
| Over-provisioned workloads | Identifies where CPU/memory requests far exceed actual p95 usage — quantified in estimated USD/month wasted |
| OOMKill risk workloads | Flags workloads approaching memory limits before they crash |
| HPA at max replicas | Surfaces capacity ceiling before it becomes an availability incident |
| Right-size recommendations | Suggests adjusted requests based on observed p95 usage with a 20% headroom buffer |

Cost rates are configurable to match your actual cloud pricing (on-demand,
reserved, or spot). Default rates reflect approximate AWS on-demand pricing.

**Waste threshold:** Only workloads with estimated monthly waste above a
configurable minimum (default $10/month) are included — low-signal findings are
filtered automatically.

---

## Noise Suppression

PodWatcher has four independent suppression layers that work together to ensure
every alert that reaches your team is actionable:

| Layer | What it does |
|---|---|
| Anti-flap back-off | Exponentially increasing hold-off per pod restart — prevents alert floods during crash loops |
| Fingerprint deduplication | Re-alerts suppressed when the failure reason is identical to a previously dispatched alert |
| Workload cooldown | 5-minute cooldown per workload — re-alerts only when the failure mode changes |
| Blast-radius mute | During node or DNS outages, P2 app-tier alerts are suppressed to prevent storm. P1 alerts always bypass this gate |

---

## State Reconstruction on Restart

If PodWatcher itself restarts (rolling upgrade, node eviction, OOMKill), it
reconstructs its operational state by reading Kubernetes Warning events from
the last two hours — a read-only operation requiring no persistent storage.

This means:
- Cooldown timers are restored — no duplicate alert burst on restart
- TTR calculation continuity is preserved — RESOLVED cards remain accurate
- No missed alerts for incidents that started before the restart

---

## Security & Data Isolation

| Property | Detail |
|---|---|
| Data residency | All processing inside your VPC — no telemetry, no phone-home |
| Outbound traffic | Encrypted alert payloads to your Teams/Slack/PagerDuty endpoint only |
| Alert payload | Kubernetes metadata only — namespace, pod name, node, exit code, log snippet. No credentials, secrets, or cluster config |
| RBAC | Dedicated ServiceAccount with least-privilege read-only permissions. Write access scoped only to coordination.k8s.io/leases in the release namespace (leader election) |
| Container security | Non-root (UID 10001), read-only root filesystem, all capabilities dropped, seccomp RuntimeDefault |
| Compliance | GDPR, HIPAA, FedRAMP, and air-gapped deployments supported — no shared tenancy |

---

## High Availability

| Feature | Detail |
|---|---|
| Single replica | Default — sufficient for most production clusters |
| HA mode (2 replicas) | Leader election via Kubernetes coordination.k8s.io/leases — only the leader dispatches alerts, standby promotes within 30 seconds |
| Verified load | 100 simultaneous pod crashes — 87Mi peak memory (17% of limit), 45m peak CPU (11% of limit), zero missed alerts |

See [ha/HA.md](ha/HA.md) for scale-up and scale-down instructions.

---

## Prometheus Metrics Endpoint

PodWatcher exposes a `/metrics` endpoint on port 8080 (Prometheus text format):

| Metric | Description |
|---|---|
| `podwatcher_alerts_total` | Total alerts dispatched |
| `podwatcher_p1_total` | P1 critical alerts dispatched |
| `podwatcher_teams_dispatched_total` | Teams webhook deliveries |
| `podwatcher_slack_dispatched_total` | Slack webhook deliveries |
| `podwatcher_webhook_errors_total` | Webhook delivery failures |
| `podwatcher_alert_queue_depth` | Current alert queue depth |
| `podwatcher_leader_election_is_leader` | 1 if this pod is the current leader |
| `podwatcher_genai_tokens_per_sec` | Per-workload token throughput |
| `podwatcher_genai_ttft_ms` | Per-workload time to first token |
| `podwatcher_genai_success_rate_pct` | Per-workload inference success rate |

A liveness probe (`/healthz`) and readiness probe (`/readyz`) are included.

---

## Supported Platforms

| Platform | Supported |
|---|---|
| Amazon EKS | Yes — including AWS Marketplace IRSA billing |
| Azure AKS | Yes |
| Google GKE / GKE Autopilot | Yes |
| Red Hat OpenShift | Yes |
| Self-managed Kubernetes | Yes |
| Minimum Kubernetes version | 1.21+ |

---

## What PodWatcher Is Not

PodWatcher is an **incident intelligence layer**, not a metrics store or
dashboard platform. It does not replace Prometheus, Datadog, or CloudWatch.

It fills the gap those tools share: knowing what broke, why it broke, and what
to do — the moment it happens — delivered to the channel your team already uses.

For historical trend analysis, SLO compliance reporting, and executive
dashboards on Amazon Managed Grafana, see the companion product:
**EKS Observability Accelerator** — available separately on AWS Marketplace.

---

## Pricing

| Plan | Clusters | Monthly |
|---|---|---|
| Starter | 1 | $199 |
| Growth | Up to 5 | $799 |
| Scale | Up to 20 | $2,499 |
| Enterprise | Unlimited + SLA | $5,999 |

Available on [AWS Marketplace](https://aws.amazon.com/marketplace).
